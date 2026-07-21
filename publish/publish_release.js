#!/usr/bin/env node

"use strict";

/*
 * Publish release files through the normal websites using a private Chrome
 * profile. This intentionally uses the browser UI instead of undocumented
 * HTTP requests, so no session data needs to be handled by this script.
 */

const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const net = require("node:net");
const readline = require("node:readline");
const {spawn} = require("node:child_process");

const repoRoot = path.resolve(__dirname, "..");
const defaultConfigPath = path.join(repoRoot, "publish", "config.local.json");
const defaultProfilePath = path.join(
    process.env.XDG_STATE_HOME || path.join(os.homedir(), ".local", "state"),
    "krisis-knightmare",
    "publisher-browser"
);

const sleep = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

function usage() {
    console.log(`Usage: node publish/publish_release.js [options]

Options:
  --config PATH       Local publisher config (default: publish/config.local.json)
  --site SITE         gamejolt, gamebanana, or all (default: all)
  --login             Open the selected sites' login pages and wait for manual login
  --dry-run           Open pages and inspect them without selecting or uploading files
  --keep-browser      Leave the isolated Chrome window open after the script exits
  --help              Show this help

The script never accepts, prints, or sends cookies or access tokens. Login is
performed by you in the isolated Chrome profile on its first use.`);
}

function parseArgs(argv) {
    const options = {
        configPath: defaultConfigPath,
        site: "all",
        login: false,
        dryRun: false,
        keepBrowser: false
    };

    for (let index = 0; index < argv.length; index += 1) {
        const argument = argv[index];
        if (argument === "--") {
            continue;
        }
        if (argument === "--help" || argument === "-h") {
            usage();
            process.exit(0);
        }
        if (argument === "--dry-run") {
            options.dryRun = true;
            continue;
        }
        if (argument === "--login") {
            options.login = true;
            continue;
        }
        if (argument === "--keep-browser") {
            options.keepBrowser = true;
            continue;
        }
        if (argument === "--config") {
            options.configPath = path.resolve(repoRoot, requireArgument(argv, ++index, argument));
            continue;
        }
        if (argument.startsWith("--config=")) {
            options.configPath = path.resolve(repoRoot, argument.slice("--config=".length));
            continue;
        }
        if (argument === "--site") {
            options.site = requireArgument(argv, ++index, argument);
            continue;
        }
        if (argument.startsWith("--site=")) {
            options.site = argument.slice("--site=".length);
            continue;
        }
        throw new Error(`Unknown option: ${argument}`);
    }

    if (!["all", "gamejolt", "gamebanana"].includes(options.site)) {
        throw new Error(`Invalid --site value: ${options.site}`);
    }
    return options;
}

function requireArgument(argv, index, option) {
    if (index >= argv.length || argv[index].startsWith("-")) {
        throw new Error(`${option} requires a value`);
    }
    return argv[index];
}

function readConfig(configPath) {
    if (!fs.existsSync(configPath)) {
        throw new Error(`Publisher config not found: ${displayPath(configPath)}\nCopy publish/config.example.json to publish/config.local.json and edit it.`);
    }

    let config;
    try {
        config = JSON.parse(fs.readFileSync(configPath, "utf8"));
    } catch (error) {
        throw new Error(`Could not parse publisher config ${displayPath(configPath)}: ${error.message}`);
    }
    if (!config || typeof config !== "object" || Array.isArray(config)) {
        throw new Error("Publisher config must contain a JSON object");
    }
    return config;
}

function displayPath(filePath) {
    const absolutePath = path.resolve(filePath);
    const relativePath = path.relative(repoRoot, absolutePath);
    if (relativePath && !relativePath.startsWith("..") && !path.isAbsolute(relativePath)) {
        return relativePath;
    }
    return absolutePath;
}

function resolveFile(filePath) {
    if (typeof filePath !== "string" || filePath.trim() === "") {
        throw new Error("Every upload entry needs a non-empty path");
    }
    const absolutePath = path.resolve(repoRoot, filePath);
    let stats;
    try {
        stats = fs.statSync(absolutePath);
    } catch (error) {
        throw new Error(`Upload file does not exist: ${displayPath(absolutePath)}`);
    }
    if (!stats.isFile()) {
        throw new Error(`Upload path is not a regular file: ${displayPath(absolutePath)}`);
    }
    return absolutePath;
}

function requireObject(value, name) {
    if (!value || typeof value !== "object" || Array.isArray(value)) {
        throw new Error(`${name} must be an object`);
    }
    return value;
}

function requireString(value, name) {
    if (typeof value !== "string" || value.trim() === "") {
        throw new Error(`${name} must be a non-empty string`);
    }
    return value.trim();
}

function requireSiteUrl(value, name, hostname) {
    const url = requireString(value, name);
    let parsed;
    try {
        parsed = new URL(url);
    } catch {
        throw new Error(`${name} must be a valid HTTPS URL`);
    }
    if (parsed.protocol !== "https:" || (parsed.hostname !== hostname && !parsed.hostname.endsWith(`.${hostname}`))) {
        throw new Error(`${name} must point to ${hostname} over HTTPS`);
    }
    if (parsed.username || parsed.password || parsed.hash) {
        throw new Error(`${name} must not contain credentials or a hash fragment`);
    }
    return parsed.toString();
}

function getGameJoltBuilds(config) {
    const gamejolt = requireObject(config.gamejolt, "gamejolt");
    const gameId = requireString(gamejolt.game_id, "gamejolt.game_id");
    if (!Array.isArray(gamejolt.builds) || gamejolt.builds.length === 0) {
        throw new Error("gamejolt.builds must contain at least one upload entry");
    }

    return gamejolt.builds.map((build, index) => {
        const item = requireObject(build, `gamejolt.builds[${index}]`);
        return {
            gameId,
            packageId: requireString(item.package_id, `gamejolt.builds[${index}].package_id`),
            releaseId: requireString(item.release_id, `gamejolt.builds[${index}].release_id`),
            filePath: resolveFile(item.path),
            pageUrl: requireSiteUrl(item.page_url || `https://gamejolt.com/dashboard/games/${encodeURIComponent(gameId)}/packages/${encodeURIComponent(item.package_id)}/releases/${encodeURIComponent(item.release_id)}/edit`, `gamejolt.builds[${index}].page_url`, "gamejolt.com")
        };
    });
}

function getGameBananaConfig(config) {
    const gamebanana = requireObject(config.gamebanana, "gamebanana");
    const modId = requireString(gamebanana.mod_id, "gamebanana.mod_id");
    const configuredPaths = gamebanana.paths ?? (gamebanana.path === undefined ? [] : [gamebanana.path]);
    if (!Array.isArray(configuredPaths) || configuredPaths.length === 0) {
        throw new Error("gamebanana.paths must contain at least one upload file");
    }
    return {
        modId,
        filePaths: configuredPaths.map(resolveFile),
        updatePageUrl: requireSiteUrl(gamebanana.update_page_url || gamebanana.page_url || `https://gamebanana.com/mods/updates/${encodeURIComponent(modId)}`, "gamebanana.update_page_url", "gamebanana.com"),
        fileManagerUrl: requireSiteUrl(gamebanana.file_manager_url || `https://gamebanana.com/mods/edit/${encodeURIComponent(modId)}`, "gamebanana.file_manager_url", "gamebanana.com")
    };
}

function findFreePort() {
    return new Promise((resolve, reject) => {
        const server = net.createServer();
        server.once("error", reject);
        server.listen(0, "127.0.0.1", () => {
            const address = server.address();
            const port = address && typeof address === "object" ? address.port : null;
            server.close((error) => error ? reject(error) : resolve(port));
        });
    });
}

async function waitForJson(url, timeoutMilliseconds) {
    const startedAt = Date.now();
    let lastError;
    while (Date.now() - startedAt < timeoutMilliseconds) {
        try {
            const response = await fetch(url);
            if (response.ok) {
                return await response.json();
            }
            lastError = new Error(`HTTP ${response.status}`);
        } catch (error) {
            lastError = error;
        }
        await sleep(100);
    }
    throw new Error(`Chrome DevTools endpoint did not start: ${lastError ? lastError.message : "timeout"}`);
}

function findChrome() {
    const candidates = [
        process.env.KRISIS_CHROME_BIN,
        "/opt/google/chrome/google-chrome",
        "/usr/bin/google-chrome",
        "/usr/bin/chromium",
        "/usr/bin/chromium-browser"
    ].filter(Boolean);
    const executable = candidates.find((candidate) => fs.existsSync(candidate));
    if (!executable) {
        throw new Error("Could not find Chrome/Chromium. Set KRISIS_CHROME_BIN to its executable path.");
    }
    return executable;
}

async function launchChrome() {
    const port = await findFreePort();
    const profilePath = process.env.KRISIS_PUBLISH_PROFILE || defaultProfilePath;
    fs.mkdirSync(profilePath, {recursive: true, mode: 0o700});

    const chrome = spawn(findChrome(), [
        `--remote-debugging-port=${port}`,
        "--remote-allow-origins=http://127.0.0.1",
        `--user-data-dir=${profilePath}`,
        "--no-first-run",
        "--no-default-browser-check",
        "about:blank"
    ], {
        stdio: "ignore",
        detached: false
    });

    let version;
    let targets;
    try {
        version = await waitForJson(`http://127.0.0.1:${port}/json/version`, 15000);
        targets = await waitForJson(`http://127.0.0.1:${port}/json/list`, 5000);
    } catch (error) {
        chrome.kill();
        throw error;
    }
    const target = targets.find((item) => item.type === "page" && item.webSocketDebuggerUrl);
    if (!target) {
        chrome.kill();
        throw new Error("Chrome started without a debuggable page target");
    }

    console.log(`Opened isolated Chrome profile: ${displayPath(profilePath)}`);
    console.log(`Browser: ${version.Browser || "Chrome"}`);
    return {chrome, target};
}

class CdpConnection {
    constructor(webSocketUrl) {
        this.socket = new WebSocket(webSocketUrl);
        this.nextId = 1;
        this.pending = new Map();
        this.events = new Map();
        this.opened = new Promise((resolve, reject) => {
            this.socket.addEventListener("open", resolve, {once: true});
            this.socket.addEventListener("error", reject, {once: true});
        });
        this.socket.addEventListener("message", (event) => this.handleMessage(event.data));
        this.socket.addEventListener("close", () => {
            for (const pending of this.pending.values()) {
                pending.reject(new Error("Chrome DevTools connection closed"));
            }
            this.pending.clear();
        });
    }

    async call(method, params = {}) {
        await this.opened;
        const id = this.nextId++;
        return new Promise((resolve, reject) => {
            this.pending.set(id, {resolve, reject});
            this.socket.send(JSON.stringify({id, method, params}));
        });
    }

    on(method, handler) {
        const handlers = this.events.get(method) || new Set();
        handlers.add(handler);
        this.events.set(method, handlers);
        return () => handlers.delete(handler);
    }

    waitFor(method, predicate = () => true, timeoutMilliseconds = 30000) {
        return new Promise((resolve, reject) => {
            const timer = setTimeout(() => {
                unsubscribe();
                reject(new Error(`Timed out waiting for Chrome event ${method}`));
            }, timeoutMilliseconds);
            const unsubscribe = this.on(method, (params) => {
                let matches = false;
                try {
                    matches = predicate(params);
                } catch (error) {
                    clearTimeout(timer);
                    unsubscribe();
                    reject(error);
                    return;
                }
                if (matches) {
                    clearTimeout(timer);
                    unsubscribe();
                    resolve(params);
                }
            });
        });
    }

    handleMessage(rawMessage) {
        const message = JSON.parse(rawMessage);
        if (message.id) {
            const pending = this.pending.get(message.id);
            if (!pending) return;
            this.pending.delete(message.id);
            if (message.error) {
                pending.reject(new Error(`${message.error.message} (${message.error.code})`));
            } else {
                pending.resolve(message.result || {});
            }
            return;
        }
        const handlers = this.events.get(message.method);
        if (handlers) {
            for (const handler of handlers) handler(message.params || {});
        }
    }

    close() {
        this.socket.close();
    }
}

async function evaluate(cdp, expression, options = {}) {
    const result = await cdp.call("Runtime.evaluate", {
        expression,
        awaitPromise: Boolean(options.awaitPromise),
        returnByValue: options.returnByValue !== false,
        userGesture: Boolean(options.userGesture)
    });
    if (result.exceptionDetails) {
        const description = result.exceptionDetails.exception?.description || result.exceptionDetails.text;
        throw new Error(`Page script failed: ${description}`);
    }
    if (result.result?.subtype === "error") {
        throw new Error(result.result.description || "Page script returned an error");
    }
    return result.result;
}

async function evaluateValue(cdp, expression) {
    const result = await evaluate(cdp, expression, {returnByValue: true});
    return result.value;
}

async function navigate(cdp, url) {
    console.log(`Opening ${new URL(url).origin}${new URL(url).pathname}`);
    const load = cdp.waitFor("Page.loadEventFired", () => true, 45000);
    await cdp.call("Page.navigate", {url});
    await load;
    await sleep(1500);
}

async function pageInfo(cdp) {
    return evaluateValue(cdp, `(() => ({
        url: location.href,
        fileInputs: [...document.querySelectorAll('input[type="file"]')].map((input) => ({
            accept: input.accept,
            name: input.name,
            visible: Boolean(input.offsetWidth || input.offsetHeight || input.getClientRects().length)
        })),
        loginPage: /\\/(login|register)(?:[/?#]|$)/i.test(location.pathname) ||
            Boolean(document.querySelector('input[type="password"]'))
    }))()`);
}

async function waitForUser(message) {
    const input = readline.createInterface({input: process.stdin, output: process.stdout});
    await new Promise((resolve) => input.question(`${message}\n> `, resolve));
    input.close();
}

async function ensureLoggedIn(cdp, siteName) {
    const info = await pageInfo(cdp);
    if (info.loginPage) {
        console.log(`${siteName} is asking for login in the isolated Chrome window.`);
        await waitForUser(`Log in there, then press Enter here to continue.`);
        const afterLogin = await pageInfo(cdp);
        if (afterLogin.loginPage) {
            throw new Error(`${siteName} still appears to be on a login page`);
        }
    }
}

async function initializeLogin(cdp, siteName) {
    const loginUrls = {
        gamejolt: "https://gamejolt.com/login",
        gamebanana: "https://gamebanana.com/members/account/login"
    };
    await navigate(cdp, loginUrls[siteName]);
    await waitForUser(`${siteName}: 在 Chrome 窗口中手动完成登录、验证码或 2FA，确认登录成功后按回车。`);
    const info = await pageInfo(cdp);
    if (info.loginPage) {
        console.log(`${siteName}: 页面仍像是登录页，请确认账号确实已登录；脚本不会读取账号信息。`);
    } else {
        console.log(`${siteName}: 登录状态已留在独立 Chrome profile 中。`);
    }
}

async function findFileInput(cdp) {
    const expression = `(() => {
        const inputs = [...document.querySelectorAll('input[type="file"]')];
        const score = (input) => {
            const text = [input.name, input.id, input.accept, input.getAttribute('aria-label'), input.parentElement?.innerText]
                .filter(Boolean).join(' ');
            return (input.offsetWidth || input.offsetHeight || input.getClientRects().length ? 10 : 0) +
                (/build|file|package|upload|archive|zip/i.test(text) ? 5 : 0);
        };
        return inputs.sort((left, right) => score(right) - score(left))[0] || null;
    })()`;
    const result = await evaluate(cdp, expression, {returnByValue: false});
    if (!result.objectId) return null;
    const description = await cdp.call("DOM.describeNode", {objectId: result.objectId});
    await cdp.call("Runtime.releaseObject", {objectId: result.objectId});
    return description.node?.backendNodeId || null;
}

async function chooseFiles(cdp, filePaths) {
    const backendNodeId = await findFileInput(cdp);
    if (!backendNodeId) return false;
    await cdp.call("DOM.setFileInputFiles", {backendNodeId, files: filePaths});
    return true;
}

function isGameJoltUploadRequest(url) {
    try {
        const parsed = new URL(url);
        return parsed.hostname === "gamejolt.com" && /\/site-api\/web\/dash\/developer\/games\/builds\/save\//.test(parsed.pathname);
    } catch {
        return false;
    }
}

function waitForGameJoltUpload(cdp) {
    let cancel;
    const promise = new Promise((resolve, reject) => {
        let requestId = null;
        let settled = false;
        const timer = setTimeout(() => finish(new Error("Timed out waiting for Game Jolt upload")), 180000);
        const removeRequestListener = cdp.on("Network.requestWillBeSent", (event) => {
            if (event.request?.method === "POST" && isGameJoltUploadRequest(event.request.url)) {
                requestId = event.requestId;
            }
        });
        const removeResponseListener = cdp.on("Network.responseReceived", (event) => {
            if (requestId && event.requestId === requestId) finish(null, event.response);
        });

        function finish(error, response) {
            if (settled) return;
            settled = true;
            clearTimeout(timer);
            removeRequestListener();
            removeResponseListener();
            if (error) reject(error);
            else resolve(response);
        }

        cancel = () => finish(new Error("Game Jolt upload watcher cancelled"));
    });
    return {promise, cancel: () => cancel()};
}

async function uploadGameJoltBuild(cdp, build, dryRun) {
    const pageUrl = requireString(build.pageUrl, "gamejolt page_url");
    await navigate(cdp, pageUrl);
    await ensureLoggedIn(cdp, "Game Jolt");

    const info = await pageInfo(cdp);
    console.log("Game Jolt release page is ready.");
    console.log(`File: ${displayPath(build.filePath)}`);
    console.log(`File inputs found: ${info.fileInputs.length}`);
    if (dryRun) return;

    const uploadFinished = waitForGameJoltUpload(cdp);
    if (!await chooseFiles(cdp, [build.filePath])) {
        uploadFinished.cancel();
        await uploadFinished.promise.catch(() => {});
        throw new Error("Could not find a Game Jolt file input. Open the release edit page and check its form.");
    }
    console.log("File selected; waiting for Game Jolt to finish its upload...");

    const response = await uploadFinished.promise;
    if (response.status < 200 || response.status >= 300) {
        throw new Error(`Game Jolt upload request returned HTTP ${response.status}`);
    }
    console.log(`Game Jolt upload finished (HTTP ${response.status}).`);
}

async function assistGameBanana(cdp, gamebanana, dryRun) {
    await navigate(cdp, gamebanana.updatePageUrl);
    await ensureLoggedIn(cdp, "GameBanana");

    const info = await pageInfo(cdp);
    console.log("GameBanana updates page is ready.");
    console.log(`Files to upload: ${gamebanana.filePaths.map(displayPath).join(", ")}`);
    console.log(`File inputs found before opening the update form: ${info.fileInputs.length}`);
    if (dryRun) {
        await navigate(cdp, gamebanana.fileManagerUrl);
        await ensureLoggedIn(cdp, "GameBanana file manager");
        const fileManagerInfo = await pageInfo(cdp);
        console.log(`GameBanana file manager is ready; file inputs found: ${fileManagerInfo.fileInputs.length}`);
        return;
    }

    await waitForUser("第 1 步：在 GameBanana 窗口打开 Add Update，填写 changelog 并提交 update。提交完成后回到这里按回车。");

    await navigate(cdp, gamebanana.fileManagerUrl);
    await ensureLoggedIn(cdp, "GameBanana file manager");
    const fileManagerInfo = await pageInfo(cdp);
    console.log("GameBanana file manager is ready.");
    console.log(`File inputs found: ${fileManagerInfo.fileInputs.length}`);
    await waitForUser("第 2 步：在文件管理页确认上传区域已显示，然后按回车选择新文件。");
    if (!await chooseFiles(cdp, gamebanana.filePaths)) {
        throw new Error("Could not find a GameBanana file input. Leave the file manager open and run the command again.");
    }
    console.log("Files selected in GameBanana. Wait for all uploads to finish in the browser.");
    await waitForUser("确认所有新文件上传完成后，把它们拖到文件列表顶部；完成后按回车结束。");
}

async function main() {
    const options = parseArgs(process.argv.slice(2));
    const config = options.login ? null : readConfig(options.configPath);
    const needsGameJolt = options.site === "all" || options.site === "gamejolt";
    const needsGameBanana = options.site === "all" || options.site === "gamebanana";
    const gamejoltBuilds = !options.login && needsGameJolt ? getGameJoltBuilds(config) : [];
    const gamebanana = !options.login && needsGameBanana ? getGameBananaConfig(config) : null;

    if (options.dryRun) console.log("Dry run: no local file will be selected and no upload will be triggered.");
    const browser = await launchChrome();
    const cdp = new CdpConnection(browser.target.webSocketDebuggerUrl);
    let keepBrowser = options.keepBrowser;
    try {
        await cdp.call("Page.enable");
        await cdp.call("Runtime.enable");
        await cdp.call("DOM.enable");
        await cdp.call("Network.enable");

        if (options.login) {
            if (needsGameJolt) await initializeLogin(cdp, "gamejolt");
            if (needsGameBanana) await initializeLogin(cdp, "gamebanana");
            console.log("Manual login setup finished. No files were selected or uploaded.");
        } else if (needsGameJolt) {
            for (const build of gamejoltBuilds) {
                await uploadGameJoltBuild(cdp, build, options.dryRun);
            }
        }
        if (!options.login && needsGameBanana) {
            await assistGameBanana(cdp, gamebanana, options.dryRun);
        }
        console.log("Publishing workflow finished.");
    } finally {
        cdp.close();
        if (keepBrowser) {
            browser.chrome.unref();
        } else if (browser.chrome.exitCode === null) {
            browser.chrome.kill();
        }
    }
}

main().catch((error) => {
    console.error(`Publish failed: ${error.message}`);
    process.exitCode = 1;
});
