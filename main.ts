// Pasar Malam Brainrot: the entrypoint (Node 22, standard library only).
// The game is this directory's Rojo project, built into game.rbxl with
// `rojo build default.project.json --output game.rbxl`. This program hands it in:
// it copies game.rbxl, src/, screenshots/ and PLAY.json from beside this file to
// /output and writes /output/dossier.json, the summary the judge reads, with the
// vendored make.fun library (vendor/makefun-roblox.ts, the kit's copy, unchanged).
//
// Run it as the grader does, writing out/ in place of /output:
//   mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
//
// Every name under /output starts with a letter, a digit or _ and holds only letters,
// digits, . _ and -: the grader fails an entry whose output holds any other, so a file
// such as .gitkeep or .DS_Store copied in fails it. src/ and screenshots/ are therefore
// copied without any name that starts with a dot, at any depth.

import { copyFileSync, cpSync, existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { basename, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildDossier } from './vendor/makefun-roblox.ts';

const here = fileURLToPath(new URL('.', import.meta.url));
const out = process.env.MAKEFUN_OUTPUT_DIR ?? '/output';

// Leave out every file and directory whose name starts with a dot (.gitkeep, .DS_Store, .git).
const notDotted = (path: string): boolean => !basename(path).startsWith('.');

// The place and the play link go in whole.
copyFileSync(join(here, 'game.rbxl'), join(out, 'game.rbxl'));
copyFileSync(join(here, 'PLAY.json'), join(out, 'PLAY.json'));

// The sources and the captures go in as trees, dot-names filtered out.
cpSync(join(here, 'src'), join(out, 'src'), { recursive: true, filter: notDotted });
mkdirSync(join(out, 'screenshots'), { recursive: true });
if (existsSync(join(here, 'screenshots'))) {
	cpSync(join(here, 'screenshots'), join(out, 'screenshots'), { recursive: true, filter: notDotted });
}

// The scorer's own caps (reference/gate.json): only text_max_bytes shapes the bytes;
// the others refuse an entry the scorer would refuse (more than 4 screenshots or one
// over 256 KiB; a place of more than 500000 instances, whose scripts' sources come to
// over 8 MiB or whose scripts' paths come to over 1048576 characters, in all).
writeFileSync(
	join(out, 'dossier.json'),
	buildDossier(out, {
		text_max_bytes: 65536,
		screenshots: { max: 4, max_bytes: 262144 },
		max_instances: 500000,
		scripts_max_source_bytes: 8388608,
		scripts_max_path_chars: 1048576,
	}),
);
