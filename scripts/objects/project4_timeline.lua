-- Project 4 timeline data. All times are seconds.
return {
    duration = 37.533333,

    spotlight_offset = {
        { t = 0.008005, x = 0, y = 0 },
        { t = 1.508002, x = 0, y = 360 },
        { t = 4.258002, x = -660, y = 360 },
        { t = 7.175017, x = -660, y = 1060.080078 },
        { t = 10.341003, x = 210, y = 1060.080078 },
        { t = 10.508018, x = 212, y = 1025, ease = "cubicBezier 0.0 0.0 0.46 1.0" },
        { t = 19.008011, x = 212, y = 1025, ease = "cubicBezier 0.7842753 0.0 1.0 1.0" },
        { t = 19.258005, x = 212, y = 1060, ease = "cubicBezier 0.0 0.0 0.0 1.0" },
        { t = 21.257989, x = 212, y = 1060 },
        { t = 21.341003, x = 179, y = 1060 },
        { t = 27.840977, x = 179, y = 1060 },
        { t = 28.175007, x = 120, y = 1176, ease = "cubicBezier 0.0 0.0 0.0 1.0" },
    },

    walk_embeds = {
        {
            id = 12362510, start = 0, finish = 7.182, loop = true,
            frames = {
                { id = 12362508, in_time = 0, out_time = 0.349, image = "1771130032919.png" },
                { id = 12362509, in_time = 0.350, out_time = 0.682, image = "1771130030206.png" },
            },
        },
        {
            id = 12362511, start = 7.183, finish = 10.515, loop = true,
            frames = {
                { id = 12362508, in_time = 0, out_time = 0.349, image = "1771131330735.png" },
                { id = 12362509, in_time = 0.350, out_time = 0.682, image = "1771131332932.png" },
            },
        },
        {
            id = 12362513, start = 10.516, finish = 13.265, loop = false,
            frames = {
                { id = 12362508, in_time = 0, out_time = 1.016, image = "1771131330735.png" },
                { id = 12362515, in_time = 1.016, out_time = 1.516, image = "1771132601587.png" },
                { id = 12362516, in_time = 1.516, out_time = 2.015, image = "1771132604773.png" },
                { id = 12362514, in_time = 2.016, out_time = 2.749, image = "1771132607448.png" },
            },
        },
    },

    character_loops = {
        {
            start = 15.816, finish = 17.349, cycle = 0.333,
            frames = {
                { in_time = 0, out_time = 0.167, image = "1771133372743.png" },
                { in_time = 0.167, out_time = 0.333, image = "1771133378174.png" },
            },
        },
        {
            start = 24.016, finish = 27.865, cycle = 1.333,
            frames = {
                { in_time = 0, out_time = 0.333, image = "1771136180689.png" },
                { in_time = 0.333, out_time = 0.667, image = "1771136184146.png" },
                { in_time = 0.667, out_time = 1.000, image = "1771136186724.png" },
                { in_time = 1.000, out_time = 1.333, image = "1771136184146.png" },
            },
        },
    },

    -- Character media frames after 13.266s, including nested walk frames.
    character_frames = {
        { id = 12362526, in_time = 13.266, out_time = 13.366, image = "1771132926492.png" },
        { id = 12362527, in_time = 13.366, out_time = 13.466, image = "1771132817006.png" },
        { id = 12362528, in_time = 13.466, out_time = 13.566, image = "1771132820401.png" },
        { id = 12362529, in_time = 13.566, out_time = 13.666, image = "1771132823905.png" },
        { id = 12362530, in_time = 13.666, out_time = 14.515, image = "1771132827949.png" },
        { id = 12362532, in_time = 14.516, out_time = 14.683, image = "1771133215265.png" },
        { id = 12362533, in_time = 14.683, out_time = 14.849, image = "1771133217601.png" },
        { id = 12362534, in_time = 14.850, out_time = 15.682, image = "1771133221900.png" },
        { id = 12362540, in_time = 15.683, out_time = 15.815, image = "1771133577607.png" },
        { id = 12362542, in_time = 17.350, out_time = 17.482, image = "1771133577607.png" },
        { id = 12362541, in_time = 17.483, out_time = 18.015, image = "1771133638251.png" },
        { id = 12362543, in_time = 18.016, out_time = 18.999, image = "1771133758741.png" },
        { id = 12362544, in_time = 19.000, out_time = 19.132, image = "1771133857408.png" },
        { id = 12362545, in_time = 19.133, out_time = 19.215, image = "1771133861439.png" },
        { id = 12362546, in_time = 19.216, out_time = 19.849, image = "1771133863948.png" },
        { id = 12362551, in_time = 19.850, out_time = 20.016, image = "1771133975772.png" },
        { id = 12362552, in_time = 20.016, out_time = 20.182, image = "1771133978472.png" },
        { id = 12362555, in_time = 20.183, out_time = 20.349, image = "1771133981465.png" },
        { id = 12362554, in_time = 20.350, out_time = 21.265, image = "1771133984048.png" },
        { id = 12362556, in_time = 21.266, out_time = 21.349, image = "1771133990145.png" },
        { id = 12362553, in_time = 21.350, out_time = 21.433, image = "1771136041159.png" },
        { id = 12362565, in_time = 21.433, out_time = 24.015, image = "1771136046779.png" },
        { id = 12362560, in_time = 27.866, out_time = 27.966, image = "1771136517844.png" },
        { id = 12362566, in_time = 27.966, out_time = 28.066, image = "1771136521118.png" },
        { id = 12362567, in_time = 28.066, out_time = 28.150, image = "1771136523594.png" },
        { id = 12362568, in_time = 28.150, out_time = 30.699, image = "1771136741547.png" },
        { id = 12362569, in_time = 30.700, out_time = 30.799, image = "1771136896285.png" },
        { id = 12362570, in_time = 30.800, out_time = 31.949, image = "1771136899940.png" },
        { id = 12362571, in_time = 31.950, out_time = 32.032, image = "1771136906130.png" },
        { id = 12362572, in_time = 32.033, out_time = 32.115, image = "1771136909636.png" },
        { id = 12362573, in_time = 32.116, out_time = 32.198, image = "1771136912833.png" },
        { id = 12362574, in_time = 32.200, out_time = 34.283, image = "1771136919265.png" },
    },

    particles = {
        {
            id = 12362626, start = 17.766, finish = 37.533333, speed = 0.5,
            count = 6, scatterSeed = 0.12, scale = 1.86, cycle = 4.0,
            keyframes = {
                radius = {{ t = -0.016, value = 0 }, { t = 0.884, value = 338, ease = "cubicBezier 0.0 0.0 0.58 1.0" }},
                evolution = {{ t = 0, value = 0 }, { t = 4.0, value = 0.09 }},
                offset = {{ t = 0.05, x = 0, y = 0 }, { t = 4.032, x = 0, y = -2200 }},
            },
        },
        { id = 12362624, start = 18.766, finish = 31.915, speed = 1.0, count = 3, scatterSeed = 0.31, scale = 1.99, cycle = 4.0,
          keyframes = { radius = {{ t = -0.016, value = 0 }, { t = 0.884, value = 338, ease = "cubicBezier 0.0 0.0 0.58 1.0" }}, evolution = {{ t = 0, value = 0 }, { t = 4.0, value = 0.09 }}, offset = {{ t = 0.05, x = 0, y = 0 }, { t = 4.032, x = 0, y = -2200 }} } },
        { id = 12362625, start = 19.766, finish = 31.915, speed = 1.0, count = 6, scatterSeed = 0.57, scale = 1.99, cycle = 4.0,
          keyframes = { radius = {{ t = -0.016, value = 0 }, { t = 0.884, value = 338, ease = "cubicBezier 0.0 0.0 0.58 1.0" }}, evolution = {{ t = 0, value = 0 }, { t = 4.0, value = 0.09 }}, offset = {{ t = 0.05, x = 0, y = 0 }, { t = 4.032, x = 0, y = -2200 }} } },
        { id = 12362622, start = 19.266, finish = 31.415, speed = 1.0, count = 2, scatterSeed = 0.57, scale = 1.99, cycle = 4.0,
          keyframes = { radius = {{ t = -0.016, value = 0 }, { t = 0.884, value = 338, ease = "cubicBezier 0.0 0.0 0.58 1.0" }}, evolution = {{ t = 0, value = 0 }, { t = 4.0, value = 0.09 }}, offset = {{ t = 0.05, x = 0, y = 0 }, { t = 4.032, x = 0, y = -2200 }} } },
        { id = 12362623, start = 20.766, finish = 31.915, speed = 1.0, count = 6, scatterSeed = 1.48, scale = 1.99, cycle = 4.0,
          keyframes = { radius = {{ t = -0.016, value = 0 }, { t = 0.884, value = 338 }}, evolution = {{ t = 0, value = 0 }, { t = 4.0, value = 0.09 }}, offset = {{ t = 0.05, x = 0, y = 0 }, { t = 4.032, x = 0, y = -2200 }} } },
        { id = 12362627, start = 21.283, finish = 31.849, speed = 0.5, count = 3, scatterSeed = 0.4, scale = 1.99, cycle = 4.0,
          keyframes = { radius = {{ t = -0.016, value = 0 }, { t = 0.884, value = 338, ease = "cubicBezier 0.0 0.0 0.58 1.0" }}, evolution = {{ t = 0, value = 0 }, { t = 4.0, value = 0.09 }}, offset = {{ t = 0.05, x = 0, y = 0 }, { t = 4.032, x = 0, y = -2200 }} } },
        { id = 12362621, start = 20.266, finish = 32.265, speed = 1.0, count = 3, scatterSeed = 0.31, scale = 1.99, cycle = 4.0,
          keyframes = { radius = {{ t = -0.016, value = 0 }, { t = 0.884, value = 338, ease = "cubicBezier 0.0 0.0 0.58 1.0" }}, evolution = {{ t = 0, value = 0 }, { t = 4.0, value = 0.09 }}, offset = {{ t = 0.05, x = 0, y = 0 }, { t = 4.032, x = 0, y = -2200 }} } },
        { id = 12362620, start = 18.250, finish = 32.399, speed = 1.0, count = 3, scatterSeed = 0.12, scale = 1.86, cycle = 4.0,
          keyframes = { radius = {{ t = -0.016, value = 0 }, { t = 0.884, value = 338, ease = "cubicBezier 0.0 0.0 0.58 1.0" }}, evolution = {{ t = 0, value = 0 }, { t = 4.0, value = 0.09 }}, offset = {{ t = 0.05, x = 0, y = 0 }, { t = 4.032, x = 0, y = -2200 }} } },
    },
}
