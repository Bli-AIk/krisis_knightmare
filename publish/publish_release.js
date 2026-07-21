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
const {execFileSync, spawn} = require("node:child_process");

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
  --review-only       Prepare GameBanana Media, then stop before Save and Update
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
        reviewOnly: false,
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
        if (argument === "--review-only") {
            options.reviewOnly = true;
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

function getProjectVersion() {
    const modPath = path.join(repoRoot, "mod.json");
    const contents = fs.readFileSync(modPath, "utf8");
    const match = contents.match(/^\s*"version"\s*:\s*"v?([^"\r\n]+)"/m);
    if (!match) throw new Error(`Could not determine project version from ${displayPath(modPath)}`);
    return match[1].trim();
}

function getGithubRepositorySlug() {
    try {
        const remote = execFileSync("git", ["config", "--get", "remote.origin.url"], {
            cwd: repoRoot,
            encoding: "utf8",
            stdio: ["ignore", "pipe", "ignore"]
        }).trim();
        const match = remote.match(/github\.com[:/]([^/\s]+\/[^/\s]+?)(?:\.git)?$/i);
        return match ? match[1] : null;
    } catch {
        return null;
    }
}

function generateGameBananaChangelog() {
    const scriptPath = path.join(repoRoot, ".github", "scripts", "generate_release_notes.sh");
    if (!fs.existsSync(scriptPath)) {
        throw new Error(`Release notes generator not found: ${displayPath(scriptPath)}`);
    }
    const temporaryDirectory = fs.mkdtempSync(path.join(os.tmpdir(), "krisis-gamebanana-notes-"));
    const outputPath = path.join(temporaryDirectory, "release-notes.md");
    try {
        const environment = {...process.env};
        if (!environment.GITHUB_REPOSITORY) {
            environment.GITHUB_REPOSITORY = getGithubRepositorySlug() || "local/local";
        }
        execFileSync(scriptPath, [`v${getProjectVersion()}`, outputPath], {
            cwd: repoRoot,
            env: environment,
            encoding: "utf8",
            stdio: ["ignore", "pipe", "pipe"],
            maxBuffer: 4 * 1024 * 1024
        });
        const generated = fs.readFileSync(outputPath, "utf8");
        const changelog = generated.match(/<summary><strong>CHANGELOG<\/strong><\/summary>\s*([\s\S]*?)\s*<\/details>/i)?.[1]?.trim();
        if (!changelog) throw new Error("Generated release notes do not contain a CHANGELOG section");
        return changelog;
    } catch (error) {
        throw new Error(`Could not generate GameBanana changelog: ${error.message}`);
    } finally {
        fs.rmSync(temporaryDirectory, {recursive: true, force: true});
    }
}

function getGameJoltPlatforms(value, filePath, name) {
    const platforms = value === undefined
        ? (/(?:release-win64|windows-?64)/i.test(path.basename(filePath)) ? ["windows_64"] : ["other"])
        : value;
    if (!Array.isArray(platforms) || platforms.length === 0 || platforms.some((platform) => !["windows", "windows_64", "mac", "mac_64", "linux", "linux_64", "other"].includes(platform))) {
        throw new Error(`${name} must contain valid Game Jolt platforms`);
    }
    return [...new Set(platforms)];
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
    const versionNumber = requireString(gamejolt.version_number || getProjectVersion(), "gamejolt.version_number");
    const updateVersion = gamejolt.update_version === true;
    if (!Array.isArray(gamejolt.builds) || gamejolt.builds.length === 0) {
        throw new Error("gamejolt.builds must contain at least one upload entry");
    }

    return gamejolt.builds.map((build, index) => {
        const item = requireObject(build, `gamejolt.builds[${index}]`);
        const releaseId = requireString(item.release_id, `gamejolt.builds[${index}].release_id`);
        if (releaseId !== "new" && !/^\d+$/.test(releaseId)) {
            throw new Error(`gamejolt.builds[${index}].release_id must be a numeric Game Jolt release ID or "new"`);
        }
        const filePath = resolveFile(item.path);
        return {
            gameId,
            versionNumber,
            updateVersion,
            packageId: requireString(item.package_id, `gamejolt.builds[${index}].package_id`),
            releaseId,
            filePath,
            platforms: getGameJoltPlatforms(item.platforms, filePath, `gamejolt.builds[${index}].platforms`),
            skipUpload: item.skip_upload === true,
            pageUrl: releaseId === "new" ? null : requireSiteUrl(item.page_url || `https://gamejolt.com/dashboard/games/${encodeURIComponent(gameId)}/packages/${encodeURIComponent(item.package_id)}/releases/${encodeURIComponent(releaseId)}/edit`, `gamejolt.builds[${index}].page_url`, "gamejolt.com")
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
        version: `v${gamebanana.version || getProjectVersion()}`.replace(/^vv/, "v"),
        title: gamebanana.title || `Update v${gamebanana.version || getProjectVersion()}`.replace(/^vv/, "v"),
        blurb: gamebanana.blurb || gamebanana.changelog || generateGameBananaChangelog(),
        significant: gamebanana.significant_update !== false,
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

async function openGameBananaUpdateForm(cdp) {
    const formReady = waitForGameBananaUpdateForm(cdp);
    const clicked = await evaluate(cdp, `(() => {
        if (document.getElementById("UpsertUpdateForm")) return true;
        const button = [...document.querySelectorAll("button")].find((candidate) =>
            /^add update$/i.test((candidate.innerText || "").replace(/\\s+/g, " ").trim())
        );
        if (!button) return false;
        button.click();
        return true;
    })()`, {userGesture: true});
    if (!clicked.value) {
        formReady.cancel();
        await formReady.promise.catch(() => {});
        throw new Error("Could not find GameBanana's Add Update button");
    }
    await formReady.promise;
}

function waitForGameBananaUpdateForm(cdp, timeoutMilliseconds = 60000) {
    let cancel;
    const promise = new Promise((resolve, reject) => {
        const deadline = Date.now() + timeoutMilliseconds;
        const check = async () => {
            try {
                const ready = await evaluateValue(cdp, `(() => {
                    const form = document.getElementById("UpsertUpdateForm");
                    const editor = form?.querySelector('[contenteditable="true"]');
                    return Boolean(form && form.querySelector("#_sName") && form.querySelector("#_sVersion") && editor);
                })()`);
                if (ready) {
                    finish(null);
                    return;
                }
                if (Date.now() >= deadline) {
                    finish(new Error(`GameBanana Add Update form did not load within ${timeoutMilliseconds / 1000} seconds`));
                    return;
                }
                timer = setTimeout(check, 300);
            } catch (error) {
                finish(error);
            }
        };
        let timer = setTimeout(check, 0);

        function finish(error) {
            clearTimeout(timer);
            if (error) reject(error);
            else resolve();
        }

        cancel = () => finish(new Error("GameBanana Add Update form watcher cancelled"));
    });
    return {promise, cancel: () => cancel()};
}

async function waitForGameBananaMedia(cdp, timeoutMilliseconds = 60000) {
    const deadline = Date.now() + timeoutMilliseconds;
    while (Date.now() < deadline) {
        const state = await evaluateValue(cdp, `(() => {
            const tab = [...document.querySelectorAll("li.CategoryTab, [role=tab]")].find((candidate) =>
                /^media(?:\\s|$)/i.test((candidate.innerText || candidate.textContent || "").replace(/\\s+/g, " ").trim())
            );
            const pane = [...document.querySelectorAll(".MediaPane")].find((candidate) => candidate.classList.contains("Selected"));
            const files = document.getElementById("Files");
            return {
                tab: Boolean(tab),
                selected: Boolean(tab && (tab.classList.contains("Selected") || pane)),
                files: Boolean(files && files.querySelector('input[type="file"]') && files.querySelector("ul.AdvancedUploadedFiles"))
            };
        })()`);
        if (state.tab && !state.selected) {
            await evaluate(cdp, `(() => {
                const tab = [...document.querySelectorAll("li.CategoryTab, [role=tab]")].find((candidate) =>
                    /^media(?:\\s|$)/i.test((candidate.innerText || candidate.textContent || "").replace(/\\s+/g, " ").trim())
                );
                if (!tab) return false;
                tab.click();
                return true;
            })()`, {userGesture: true});
        }
        if (state.files) return;
        await sleep(500);
    }
    throw new Error(`GameBanana Media form did not load within ${timeoutMilliseconds / 1000} seconds`);
}

async function getGameBananaMediaRows(cdp) {
    return evaluateValue(cdp, `(() => {
        const list = document.querySelector("ul.AdvancedUploadedFiles");
        if (!list) return [];
        return [...list.children].map((row, index) => {
            const link = row.querySelector('a[title="Download"]');
            const size = row.querySelector("itemcount")?.getAttribute("title") || "";
            return {
                index,
                filename: (link?.textContent || "").trim(),
                href: link?.href || null,
                size: /^(\\d+)/.test(size) ? Number(size.match(/^(\\d+)/)[1]) : null,
                version: row.querySelector(".VersionInput")?.value || "",
                fileId: row.querySelector('input[name="_idFileRow"]')?.value || "",
                added: row.querySelector(".RedColor")?.textContent?.trim() || ""
            };
        }).filter((row) => row.filename);
    })()`);
}

function gameBananaFileNameMatches(actualName, expectedName) {
    const actual = actualName.toLowerCase();
    const expected = path.basename(expectedName).toLowerCase();
    if (actual === expected) return true;
    const extension = path.extname(expected);
    const stem = expected.slice(0, -extension.length).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const escapedExtension = extension.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    return new RegExp(`^${stem}_[a-z0-9-]+${escapedExtension}$`, "i").test(actual);
}

function findGameBananaMediaRow(rows, filePath) {
    const fileSize = fs.statSync(filePath).size;
    return rows.filter((row) => row.size === fileSize && gameBananaFileNameMatches(row.filename, path.basename(filePath))).at(-1) || null;
}

async function findGameBananaFileInput(cdp) {
    const result = await evaluate(cdp, `(() => document.getElementById("Files")?.querySelector('input[type="file"]') || null)()`, {returnByValue: false});
    if (!result.objectId) return null;
    const description = await cdp.call("DOM.describeNode", {objectId: result.objectId});
    await cdp.call("Runtime.releaseObject", {objectId: result.objectId});
    return description.node?.backendNodeId || null;
}

async function chooseGameBananaFiles(cdp, filePaths) {
    const backendNodeId = await findGameBananaFileInput(cdp);
    if (!backendNodeId) return false;
    await cdp.call("DOM.setFileInputFiles", {backendNodeId, files: filePaths});
    await evaluate(cdp, `(() => {
        const input = document.getElementById("Files")?.querySelector('input[type="file"]');
        if (!input) return false;
        input.dispatchEvent(new Event("input", {bubbles: true}));
        input.dispatchEvent(new Event("change", {bubbles: true}));
        return true;
    })()`, {userGesture: true});
    return true;
}

async function uploadGameBananaFiles(cdp, gamebanana) {
    await navigate(cdp, gamebanana.fileManagerUrl);
    await ensureLoggedIn(cdp, "GameBanana file manager");
    await waitForGameBananaMedia(cdp);

    let rows = await getGameBananaMediaRows(cdp);
    const missing = gamebanana.filePaths.filter((filePath) => !findGameBananaMediaRow(rows, filePath));
    for (const filePath of missing) {
        console.log(`Uploading GameBanana file: ${displayPath(filePath)}`);
        if (!await chooseGameBananaFiles(cdp, [filePath])) {
            throw new Error("Could not find GameBanana's Media file input");
        }
        const deadline = Date.now() + 600000;
        while (Date.now() < deadline) {
            rows = await getGameBananaMediaRows(cdp);
            if (findGameBananaMediaRow(rows, filePath)) break;
            await sleep(1000);
        }
        if (!findGameBananaMediaRow(rows, filePath)) {
            throw new Error(`GameBanana did not finish uploading ${path.basename(filePath)} within 600 seconds`);
        }
        console.log(`GameBanana upload finished: ${path.basename(filePath)}.`);
    }

    rows = await getGameBananaMediaRows(cdp);
    const targetRows = gamebanana.filePaths.map((filePath) => findGameBananaMediaRow(rows, filePath));
    if (targetRows.some((row) => !row)) {
        throw new Error("Could not identify all GameBanana files after upload");
    }
    return targetRows;
}

async function configureGameBananaMedia(cdp, gamebanana, targetRows) {
    const targetDescriptors = gamebanana.filePaths.map((filePath) => ({
        filename: path.basename(filePath),
        size: fs.statSync(filePath).size
    }));
    const version = gamebanana.version;
    const result = await evaluate(cdp, `(() => {
        const list = document.querySelector("ul.AdvancedUploadedFiles");
        if (!list) return {error: "missing file list"};
        const descriptors = ${JSON.stringify(targetDescriptors)};
        const rows = [...list.children];
        const matchesName = (actual, expected) => {
            const actualLower = actual.toLowerCase();
            const expectedLower = expected.toLowerCase();
            if (actualLower === expectedLower) return true;
            const extensionIndex = expectedLower.lastIndexOf(".");
            const stem = expectedLower.slice(0, extensionIndex);
            const extension = expectedLower.slice(extensionIndex);
            const suffix = actualLower.slice(stem.length + 1, actualLower.length - extension.length);
            return actualLower.startsWith(stem + "_") && actualLower.endsWith(extension) && /^[a-z0-9-]+$/.test(suffix);
        };
        const matches = (row, descriptor) => {
            const link = row.querySelector('a[title="Download"]');
            const rawSize = row.querySelector("itemcount")?.getAttribute("title") || "";
            const size = rawSize.match(/^(\\d+)/)?.[1];
            return Boolean(link && size && Number(size) === descriptor.size && matchesName(link.textContent.trim(), descriptor.filename));
        };
        const targets = descriptors.map((descriptor) => rows.filter((row) => matches(row, descriptor)).at(-1));
        if (targets.some((row) => !row)) return {error: "missing target file row"};
        for (const row of targets) {
            const input = row.querySelector(".VersionInput");
            if (!input) return {error: "missing version input"};
            const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value").set;
            setter.call(input, ${JSON.stringify(version)});
            input.dispatchEvent(new Event("input", {bubbles: true}));
            input.dispatchEvent(new Event("change", {bubbles: true}));
        }
        const anchor = list.firstElementChild;
        let insertionPoint = anchor;
        for (const row of targets) {
            list.insertBefore(row, insertionPoint);
            insertionPoint = row.nextElementSibling;
        }
        const jq = window.jQuery || window.$;
        if (jq && jq.fn?.sortable) jq(list).sortable("refreshPositions");
        list.dispatchEvent(new Event("change", {bubbles: true}));
        const state = [...list.children].slice(0, ${targetDescriptors.length}).map((row) => ({
            fileId: row.querySelector('input[name="_idFileRow"]')?.value || "",
            filename: row.querySelector('a[title="Download"]')?.textContent?.trim() || "",
            size: Number((row.querySelector("itemcount")?.getAttribute("title") || "").match(/^(\\d+)/)?.[1] || 0),
            version: row.querySelector(".VersionInput")?.value || ""
        }));
        return {
            state,
            valid: state.length === descriptors.length && state.every((row, index) => {
                const descriptor = descriptors[index];
                const actual = row.filename.toLowerCase();
                const expected = descriptor.filename.toLowerCase();
                const extensionIndex = expected.lastIndexOf(".");
                const stem = expected.slice(0, extensionIndex);
                const extension = expected.slice(extensionIndex);
                const suffix = actual.slice(stem.length + 1, actual.length - extension.length);
                const nameMatches = actual === expected || (actual.startsWith(stem + "_") && actual.endsWith(extension) && /^[a-z0-9-]+$/.test(suffix));
                return nameMatches && row.size === descriptor.size && row.version === ${JSON.stringify(version)};
            })
        };
    })()`, {userGesture: true});
    if (result.value?.error || !result.value?.valid) {
        throw new Error(`Could not set GameBanana file versions/order: ${result.value?.error || "verification failed"}`);
    }
    console.log(`GameBanana files set to ${version}; order is ${gamebanana.filePaths.map((filePath) => path.basename(filePath)).join(", ")}.`);
}

function waitForGameBananaPost(cdp, modId, kind, timeoutMilliseconds = 120000) {
    let cancel;
    const promise = new Promise((resolve, reject) => {
        let requestId = null;
        let settled = false;
        const pathPrefix = kind === "media" ? `/mods/edit/${modId}` : `/mods/updates/${modId}`;
        const timer = setTimeout(() => finish(new Error(`Timed out waiting for GameBanana ${kind} save`)), timeoutMilliseconds);
        const removeRequestListener = cdp.on("Network.requestWillBeSent", (event) => {
            const request = event.request;
            if (request?.method === "POST") {
                try {
                    const url = new URL(request.url);
                    if (url.hostname === "gamebanana.com" && url.pathname === pathPrefix) requestId = event.requestId;
                } catch {
                    // Ignore non-URL requests.
                }
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

        cancel = () => finish(new Error(`GameBanana ${kind} save watcher cancelled`));
    });
    return {promise, cancel: () => cancel()};
}

async function saveGameBananaMedia(cdp, gamebanana) {
    const saveFinished = waitForGameBananaPost(cdp, gamebanana.modId, "media");
    const clicked = await evaluate(cdp, `(() => {
        const form = document.querySelector("form.MainForm");
        const button = form && [...form.querySelectorAll('button[type="submit"]')].find((candidate) =>
            /^save$/i.test((candidate.innerText || candidate.value || "").replace(/\\s+/g, " ").trim())
        );
        if (!button || button.disabled) return false;
        button.click();
        return true;
    })()`, {userGesture: true});
    if (!clicked.value) {
        saveFinished.cancel();
        await saveFinished.promise.catch(() => {});
        throw new Error("Could not find GameBanana's Media Save button");
    }
    const response = await saveFinished.promise;
    if (response.status < 200 || response.status >= 400) {
        throw new Error(`GameBanana Media save returned HTTP ${response.status}`);
    }
    await navigate(cdp, gamebanana.fileManagerUrl);
    await ensureLoggedIn(cdp, "GameBanana file manager");
    await waitForGameBananaMedia(cdp);
    const rows = await getGameBananaMediaRows(cdp);
    console.log("GameBanana Media changes saved.");
    return rows;
}

async function setGameBananaUpdateFields(cdp, gamebanana, targetRows) {
    const targetFileIds = targetRows.map((row) => row.fileId);
    const result = await evaluate(cdp, `(async () => {
        const form = document.getElementById("UpsertUpdateForm");
        if (!form) return {error: "missing update form"};
        const setInput = (selector, value) => {
            const input = form.querySelector(selector);
            if (!input) return false;
            const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value").set;
            setter.call(input, value);
            input.dispatchEvent(new Event("input", {bubbles: true}));
            input.dispatchEvent(new Event("change", {bubbles: true}));
            return input.value === value;
        };
        if (!setInput("#_sName", ${JSON.stringify(gamebanana.title)}) || !setInput("#_sVersion", ${JSON.stringify(gamebanana.version)})) {
            return {error: "missing title or version input"};
        }
        const targetIds = new Set(${JSON.stringify(targetFileIds)});
        const fileValues = [...form.querySelectorAll('input[id^="File_"]')].map((input) => input.value);
        for (const value of fileValues) {
            const currentForm = document.getElementById("UpsertUpdateForm");
            const input = [...currentForm.querySelectorAll('input[id^="File_"]')].find((candidate) => candidate.value === value);
            if (input && input.checked !== targetIds.has(value)) {
                input.click();
                await new Promise((resolve) => setTimeout(resolve, 500));
            }
        }
        const currentForm = document.getElementById("UpsertUpdateForm");
        const selected = [...currentForm.querySelectorAll('input[id^="File_"]')]
            .filter((input) => input.checked)
            .map((input) => input.value);
        if (selected.length !== targetIds.size || selected.some((value) => !targetIds.has(value))) {
            return {error: "could not select all related files", selected};
        }
        const significance = currentForm.querySelector("#UpdateSignificance");
        if (significance && significance.checked !== ${gamebanana.significant ? "true" : "false"}) significance.click();
        const editor = [...currentForm.querySelectorAll('[contenteditable="true"]')].find((candidate) =>
            /^blurb(?:\s|$)/i.test(candidate.closest(".StrangeBerryInput")?.querySelector("label")?.textContent?.trim() || "")
        );
        if (!editor) return {error: "missing Blurb editor"};
        editor.focus();
        const selection = window.getSelection();
        const range = document.createRange();
        range.selectNodeContents(editor);
        selection.removeAllRanges();
        selection.addRange(range);
        return {title: currentForm.querySelector("#_sName").value, version: currentForm.querySelector("#_sVersion").value, selected, editorReady: true};
    })()`, {userGesture: true, awaitPromise: true});
    if (result.value?.error) throw new Error(`Could not fill GameBanana Add Update form: ${result.value.error}`);

    await cdp.call("Input.insertText", {text: gamebanana.blurb});
    const editorText = await evaluateValue(cdp, `(() => {
        const form = document.getElementById("UpsertUpdateForm");
        const editor = [...form.querySelectorAll('[contenteditable="true"]')].find((candidate) =>
            /^blurb(?:\s|$)/i.test(candidate.closest(".StrangeBerryInput")?.querySelector("label")?.textContent?.trim() || "")
        );
        return editor?.innerText || "";
    })()`);
    if (!editorText || editorText.length < Math.min(gamebanana.blurb.length, 1)) {
        throw new Error("Could not fill GameBanana Blurb editor");
    }
    console.log(`GameBanana Add Update filled: ${gamebanana.title}, ${gamebanana.version}; CI release notes placed in Blurb (${gamebanana.blurb.length} characters).`);
}

async function waitForGameBananaUpdateSaved(cdp, gamebanana, timeoutMilliseconds = 120000) {
    const deadline = Date.now() + timeoutMilliseconds;
    while (Date.now() < deadline) {
        const state = await evaluateValue(cdp, `(() => {
            const expected = ${JSON.stringify(gamebanana.title)}.replace(/\\s+/g, " ").trim().toLowerCase();
            const headers = [...document.querySelectorAll(".UpdateHeader strong")].map((node) =>
                (node.textContent || "").replace(/\\s+/g, " ").trim().toLowerCase()
            );
            return {
                form: Boolean(document.getElementById("UpsertUpdateForm")),
                update: headers.includes(expected)
            };
        })()`);
        if (!state.form && state.update) return;
        await sleep(500);
    }
    throw new Error(`GameBanana update did not appear within ${timeoutMilliseconds / 1000} seconds`);
}

async function saveGameBananaUpdate(cdp, gamebanana) {
    const clicked = await evaluate(cdp, `(() => {
        const button = document.querySelector('button[type="submit"][form="UpsertUpdateForm"]') ||
            [...document.querySelectorAll("button")].find((candidate) =>
                candidate.type === "submit" && /^save$/i.test((candidate.innerText || candidate.value || "").trim()) && candidate.form?.id === "UpsertUpdateForm"
            );
        if (!button || button.disabled) return false;
        button.click();
        return true;
    })()`, {userGesture: true});
    if (!clicked.value) {
        throw new Error("Could not find GameBanana Add Update Save button");
    }
    await waitForGameBananaUpdateSaved(cdp, gamebanana);
    console.log("GameBanana update saved.");
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

async function waitForFileInputs(cdp, siteName, timeoutMilliseconds = 60000) {
    const deadline = Date.now() + timeoutMilliseconds;
    let info;
    while (Date.now() < deadline) {
        info = await pageInfo(cdp);
        if (info.loginPage) {
            throw new Error(`${siteName} redirected to a login page while loading`);
        }
        if (info.fileInputs.length > 0) return info;
        await sleep(500);
    }
    throw new Error(`${siteName} file form did not load within ${timeoutMilliseconds / 1000} seconds`);
}

async function waitForGameJoltNewReleaseButton(cdp, timeoutMilliseconds = 60000) {
    const deadline = Date.now() + timeoutMilliseconds;
    const expression = `(() => [...document.querySelectorAll("button")].some((button) => {
        const text = (button.innerText || "").replace(/\\s+/g, " ").trim();
        return button.classList.contains("button") &&
            button.classList.contains("-primary") &&
            button.classList.contains("-outline") &&
            button.classList.contains("-block") &&
            /new|release|version|發行|发行|版本/i.test(text);
    }))()`;
    while (Date.now() < deadline) {
        if (await evaluateValue(cdp, expression)) return;
        await sleep(500);
    }
    throw new Error(`Game Jolt package page did not load the new-release button within ${timeoutMilliseconds / 1000} seconds`);
}

async function waitForGameJoltVersionInput(cdp, timeoutMilliseconds = 60000) {
    const deadline = Date.now() + timeoutMilliseconds;
    while (Date.now() < deadline) {
        const value = await evaluateValue(cdp, "document.querySelector('input[name=version_number]')?.value ?? null");
        if (value !== null) return;
        await sleep(500);
    }
    throw new Error(`Game Jolt release editor did not load the version field within ${timeoutMilliseconds / 1000} seconds`);
}

function isGameJoltReleaseSaveRequest(url) {
    try {
        const parsed = new URL(url);
        return parsed.hostname === "gamejolt.com" && /\/site-api\/web\/dash\/developer\/games\/releases\/save\//.test(parsed.pathname);
    } catch {
        return false;
    }
}

function waitForGameJoltReleaseSave(cdp) {
    let cancel;
    const promise = new Promise((resolve, reject) => {
        let requestId = null;
        let settled = false;
        const timer = setTimeout(() => finish(new Error("Timed out waiting for Game Jolt release version save")), 120000);
        const removeRequestListener = cdp.on("Network.requestWillBeSent", (event) => {
            if (event.request?.method === "POST" && isGameJoltReleaseSaveRequest(event.request.url)) {
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

        cancel = () => finish(new Error("Game Jolt release save watcher cancelled"));
    });
    return {promise, cancel: () => cancel()};
}

async function saveGameJoltVersion(cdp, versionNumber) {
    await waitForGameJoltVersionInput(cdp);
    const saveFinished = waitForGameJoltReleaseSave(cdp);
    const result = await evaluate(cdp, `(() => {
        const input = document.querySelector('input[name="version_number"]');
        if (!input) return false;
        const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value").set;
        setter.call(input, ${JSON.stringify(versionNumber)});
        input.dispatchEvent(new Event("input", {bubbles: true}));
        input.dispatchEvent(new Event("change", {bubbles: true}));
        input.blur();
        return input.value === ${JSON.stringify(versionNumber)};
    })()`, {userGesture: true});
    if (!result.value) {
        saveFinished.cancel();
        await saveFinished.promise.catch(() => {});
        throw new Error("Could not set the Game Jolt release version field");
    }
    await sleep(300);

    const saveButtonExpression = `(() => {
        const button = [...document.querySelectorAll("button")].find((candidate) => {
            const text = (candidate.innerText || "").replace(/\\s+/g, " ").trim();
            return /save|儲存|保存/i.test(text) && /draft|release|草稿|發行|发行/i.test(text);
        });
        return Boolean(button && !button.disabled);
    })()`;
    const buttonDeadline = Date.now() + 60000;
    while (Date.now() < buttonDeadline && !await evaluateValue(cdp, saveButtonExpression)) {
        await sleep(500);
    }

    const clicked = await evaluate(cdp, `(() => {
        const button = [...document.querySelectorAll("button")].find((candidate) => {
            const text = (candidate.innerText || "").replace(/\\s+/g, " ").trim();
            return /save|儲存|保存/i.test(text) && /draft|release|草稿|發行|发行/i.test(text);
        });
        if (!button || button.disabled) return false;
        button.click();
        return true;
    })()`, {userGesture: true});
    if (!clicked.value) {
        saveFinished.cancel();
        await saveFinished.promise.catch(() => {});
        throw new Error("Could not find the Game Jolt release save button");
    }

    const response = await saveFinished.promise;
    if (response.status < 200 || response.status >= 300) {
        throw new Error(`Game Jolt release save request returned HTTP ${response.status}`);
    }
    console.log(`Game Jolt release version saved: ${versionNumber}`);
}

async function createGameJoltRelease(cdp, build, dryRun) {
    const packageUrl = `https://gamejolt.com/dashboard/games/${encodeURIComponent(build.gameId)}/packages/${encodeURIComponent(build.packageId)}`;
    await navigate(cdp, packageUrl);
    await ensureLoggedIn(cdp, "Game Jolt");
    await waitForGameJoltNewReleaseButton(cdp);
    if (dryRun) {
        console.log("Game Jolt new-release button is ready; dry run will not create a release.");
        return null;
    }

    const clicked = await evaluate(cdp, `(() => {
        const button = [...document.querySelectorAll("button")].find((candidate) => {
            const text = (candidate.innerText || "").replace(/\\s+/g, " ").trim();
            return candidate.classList.contains("button") &&
                candidate.classList.contains("-primary") &&
                candidate.classList.contains("-outline") &&
                candidate.classList.contains("-block") &&
                /new|release|version|發行|发行|版本/i.test(text);
        });
        if (!button) return false;
        button.click();
        return true;
    })()`, {userGesture: true});
    if (!clicked.value) throw new Error("Could not find Game Jolt's new-release button");

    const deadline = Date.now() + 60000;
    const releasePattern = new RegExp(`/dashboard/games/${encodeURIComponent(build.gameId)}/packages/${encodeURIComponent(build.packageId)}/releases/(\\d+)/edit`);
    while (Date.now() < deadline) {
        const currentUrl = await evaluateValue(cdp, "location.href");
        const match = currentUrl.match(releasePattern);
        if (match) {
            const release = {releaseId: match[1], pageUrl: currentUrl};
            console.log(`Game Jolt new release created: ${release.releaseId}`);
            return release;
        }
        await sleep(500);
    }
    throw new Error("Game Jolt did not open the new release editor within 60 seconds");
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

async function setGameJoltBuildPlatforms(cdp, build) {
    const fileName = path.basename(build.filePath);
    const desiredNames = build.platforms.map((platform) => `os_${platform}`);
    const deadline = Date.now() + 60000;
    while (Date.now() < deadline) {
        const state = await evaluateValue(cdp, `(() => {
            const buildForm = [...document.querySelectorAll(".game-build-form")]
                .find((form) => [...form.querySelectorAll("h5")].some((heading) => (heading.innerText || "").includes(${JSON.stringify(fileName)})));
            if (!buildForm) return null;
            const checkboxes = [...buildForm.querySelectorAll('input[type="checkbox"][name^="os_"]')];
            return {
                found: true,
                checked: checkboxes.filter((checkbox) => checkbox.checked).map((checkbox) => checkbox.name),
                names: checkboxes.map((checkbox) => checkbox.name)
            };
        })()`);
        if (state && desiredNames.every((name) => state.checked.includes(name)) && state.checked.every((name) => desiredNames.includes(name))) {
            console.log(`Game Jolt platforms set for ${fileName}: ${build.platforms.join(", ")}.`);
            return;
        }
        if (state) {
            await evaluate(cdp, `(() => {
                const buildForm = [...document.querySelectorAll(".game-build-form")]
                    .find((form) => [...form.querySelectorAll("h5")].some((heading) => (heading.innerText || "").includes(${JSON.stringify(fileName)})));
                if (!buildForm) return false;
                const desired = new Set(${JSON.stringify(desiredNames)});
                for (const checkbox of buildForm.querySelectorAll('input[type="checkbox"][name^="os_"]')) {
                    if (checkbox.checked !== desired.has(checkbox.name)) checkbox.click();
                }
                return true;
            })()`, {userGesture: true});
            await sleep(1000);
        } else {
            await sleep(500);
        }
    }
    throw new Error(`Game Jolt build platform controls did not become ready for ${fileName}`);
}

async function prepareExistingGameJoltBuild(cdp, build) {
    const formReady = waitForGameJoltBuildForm(cdp, build);
    await navigate(cdp, requireString(build.pageUrl, "gamejolt page_url"));
    await ensureLoggedIn(cdp, "Game Jolt");
    await waitForFileInputs(cdp, "Game Jolt release page");
    const formResponse = await formReady.promise;
    if (formResponse.status < 200 || formResponse.status >= 300) {
        throw new Error(`Game Jolt build form request returned HTTP ${formResponse.status}`);
    }
    await setGameJoltBuildPlatforms(cdp, build);
}

function isGameJoltUploadRequest(url) {
    try {
        const parsed = new URL(url);
        return parsed.hostname === "gamejolt.com" && /\/site-api\/web\/dash\/developer\/games\/builds\/save\//.test(parsed.pathname);
    } catch {
        return false;
    }
}

function isGameJoltBuildFormRequest(url, build) {
    try {
        const parsed = new URL(url);
        return parsed.hostname === "gamejolt.com" &&
            parsed.pathname === `/site-api/web/dash/developer/games/builds/save/${build.gameId}/${build.packageId}/${build.releaseId}`;
    } catch {
        return false;
    }
}

function waitForGameJoltBuildForm(cdp, build) {
    let cancel;
    const promise = new Promise((resolve, reject) => {
        let requestId = null;
        let settled = false;
        const timer = setTimeout(() => finish(new Error("Timed out waiting for Game Jolt build form configuration")), 60000);
        const removeRequestListener = cdp.on("Network.requestWillBeSent", (event) => {
            if (event.request?.method === "GET" && isGameJoltBuildFormRequest(event.request.url, build)) {
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

        cancel = () => finish(new Error("Game Jolt build form watcher cancelled"));
    });
    return {promise, cancel: () => cancel()};
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
    const formReady = waitForGameJoltBuildForm(cdp, build);
    await navigate(cdp, pageUrl);
    await ensureLoggedIn(cdp, "Game Jolt");

    const info = await waitForFileInputs(cdp, "Game Jolt release page");
    const formResponse = await formReady.promise;
    if (formResponse.status < 200 || formResponse.status >= 300) {
        throw new Error(`Game Jolt build form request returned HTTP ${formResponse.status}`);
    }
    await sleep(1000);
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
    await setGameJoltBuildPlatforms(cdp, build);

    const response = await uploadFinished.promise;
    if (response.status < 200 || response.status >= 300) {
        throw new Error(`Game Jolt upload request returned HTTP ${response.status}`);
    }
    console.log(`Game Jolt upload finished (HTTP ${response.status}).`);
}

async function assistGameBanana(cdp, gamebanana, dryRun, reviewOnly) {
    console.log(`Files to upload: ${gamebanana.filePaths.map(displayPath).join(", ")}`);
    if (dryRun) {
        await navigate(cdp, gamebanana.fileManagerUrl);
        await ensureLoggedIn(cdp, "GameBanana file manager");
        await waitForGameBananaMedia(cdp);
        const rows = await getGameBananaMediaRows(cdp);
        console.log(`GameBanana Media is ready; visible file rows: ${rows.length}.`);
        await navigate(cdp, gamebanana.updatePageUrl);
        await ensureLoggedIn(cdp, "GameBanana updates");
        console.log("GameBanana Updates page is ready; dry run will not open or save Add Update.");
        return;
    }

    let targetRows = await uploadGameBananaFiles(cdp, gamebanana);
    await configureGameBananaMedia(cdp, gamebanana, targetRows);
    if (reviewOnly) {
        await waitForUser("Review-only：请在浏览器中检查 Media 文件、版本号和排序；脚本不会点击 Save。检查完成后按回车退出。");
        return;
    }
    const savedRows = await saveGameBananaMedia(cdp, gamebanana);
    targetRows = gamebanana.filePaths.map((filePath) => findGameBananaMediaRow(savedRows, filePath));
    if (targetRows.some((row) => !row)) {
        throw new Error("Could not re-identify GameBanana files after Media save");
    }

    await navigate(cdp, gamebanana.updatePageUrl);
    await ensureLoggedIn(cdp, "GameBanana updates");
    await openGameBananaUpdateForm(cdp);
    await setGameBananaUpdateFields(cdp, gamebanana, targetRows);
    await saveGameBananaUpdate(cdp, gamebanana);
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
    let keepBrowser = options.keepBrowser || options.reviewOnly;
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
            let newGameJoltRelease = null;
            let checkedNewGameJoltRelease = false;
            for (const build of gamejoltBuilds) {
                if (build.releaseId === "new") {
                    if (options.dryRun) {
                        if (!checkedNewGameJoltRelease) {
                            await createGameJoltRelease(cdp, build, true);
                            checkedNewGameJoltRelease = true;
                        }
                        console.log(`Dry run: a new Game Jolt release would receive ${displayPath(build.filePath)}.`);
                        continue;
                    }
                    if (!newGameJoltRelease) {
                        newGameJoltRelease = await createGameJoltRelease(cdp, build, false);
                    }
                    if (build.skipUpload) {
                        throw new Error('gamejolt.builds cannot use skip_upload with release_id "new"');
                    }
                    await uploadGameJoltBuild(cdp, {
                        ...build,
                        releaseId: newGameJoltRelease.releaseId,
                        pageUrl: newGameJoltRelease.pageUrl
                    }, false);
                    if (!checkedNewGameJoltRelease) {
                        await saveGameJoltVersion(cdp, build.versionNumber);
                        checkedNewGameJoltRelease = true;
                    }
                } else {
                    if (build.skipUpload) {
                        if (options.dryRun) {
                            console.log(`Dry run: would configure existing Game Jolt build ${displayPath(build.filePath)} without uploading.`);
                        } else {
                            await prepareExistingGameJoltBuild(cdp, build);
                        }
                    } else {
                        await uploadGameJoltBuild(cdp, build, options.dryRun);
                    }
                    if (!options.dryRun && build.updateVersion && !checkedNewGameJoltRelease) {
                        await saveGameJoltVersion(cdp, build.versionNumber);
                        checkedNewGameJoltRelease = true;
                    }
                }
            }
        }
        if (!options.login && needsGameBanana) {
            await assistGameBanana(cdp, gamebanana, options.dryRun, options.reviewOnly);
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
