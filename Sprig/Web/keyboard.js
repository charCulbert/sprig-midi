import './compost/components/compost-piano.js';
import { noteName } from './compost/midi.js';
import { addEdgeGrips, chromeSize, clamp, connectWindow, host, post } from './panel.js';

const KEY_MIN = 13;
const KEY_MAX = 81;
const WHITE_KEY_WIDTH = 20;
const MIN_HEIGHT = 70;
const MAX_HEIGHT = 400;
const whitePitchClasses = new Set([0, 2, 4, 5, 7, 9, 11]);

const win = document.querySelector('compost-window');
const piano = document.querySelector('compost-piano');
const rangeLabel = document.querySelector('#range');
const outputLabel = document.querySelector('#output');
let rootNote = -1;
let noteCount = -1;
let anchorRight = false;

function whiteKeyBoundary(note, min, max) {
	note = clamp(Math.round(note), min, max);
	for (let distance = 0; distance < 12; ++distance) {
		const lower = note - distance;
		if (lower >= min && whitePitchClasses.has(lower % 12)) return lower;
		const upper = note + distance;
		if (upper <= max && whitePitchClasses.has(upper % 12)) return upper;
	}
	return note;
}

function keyboardWidth(root, count) {
	let whites = 0;
	for (let note = root; note < root + count; ++note) whites += whitePitchClasses.has(note % 12);
	// matches compost-piano's keyboardWidth when the range ends on white keys
	return whites * WHITE_KEY_WIDTH + 2;
}

function renderKeys() {
	if (piano.getAttribute('root-note') !== String(rootNote) || piano.getAttribute('note-count') !== String(noteCount)) {
		piano.allNotesOff();
		piano.setAttribute('root-note', String(rootNote));
		piano.setAttribute('note-count', String(noteCount));
	}
	piano.scrollLeft = anchorRight ? piano.scrollWidth : 0;
}
addEventListener('resize', renderKeys);

function setRange(root, count, { anchor = 'left', height = innerHeight } = {}) {
	count = clamp(Math.round(count), KEY_MIN, KEY_MAX);
	root = clamp(Math.round(root), 0, 127 - count);
	let top = root + count - 1;
	root = whiteKeyBoundary(root, 0, top - KEY_MIN + 1);
	top = whiteKeyBoundary(top, root + KEY_MIN - 1, Math.min(127, root + KEY_MAX - 1));
	count = top - root + 1;
	if (root !== rootNote || count !== noteCount) {
		rootNote = root;
		noteCount = count;
		rangeLabel.textContent = `${noteName(root)} · ${count}`;
		post({ type: 'keyboardRange', root, count });
	}
	anchorRight = anchor === 'right';
	const width = keyboardWidth(root, count) + chromeSize(win).width;
	// the window resizes a frame later: grow the keys now, shrink them on its resize event
	if (width >= innerWidth) renderKeys();
	post({ type: 'resize', width, height, anchor });
}

const semitones = (dx) => Math.round((dx / WHITE_KEY_WIDTH) * (12 / 7));

addEdgeGrips(win, ({ edge, dx, dy, start }) => {
	start.root ??= rootNote;
	start.count ??= noteCount;
	const { root, count } = start;
	if (edge === 'b') {
		setRange(rootNote, noteCount, { height: clamp(start.height + dy, MIN_HEIGHT, MAX_HEIGHT) });
	} else if (edge === 'r') {
		const top = whiteKeyBoundary(root + count - 1 + semitones(dx), root + KEY_MIN - 1, Math.min(127, root + KEY_MAX - 1));
		setRange(root, top - root + 1);
	} else {
		const top = root + count - 1;
		const nextRoot = whiteKeyBoundary(root + semitones(dx), Math.max(0, top - KEY_MAX + 1), top - KEY_MIN + 1);
		setRange(nextRoot, top - nextRoot + 1, { anchor: 'right' });
	}
});

const shiftOctave = (direction) => {
	setRange(rootNote + 12 * direction, noteCount);
	piano.focus({ preventScroll: true });
};
document.querySelector('#down').addEventListener('click', () => shiftOctave(-1));
document.querySelector('#up').addEventListener('click', () => shiftOctave(1));
addEventListener('keydown', (event) => {
	if (event.repeat || event.metaKey || event.altKey || event.ctrlKey || event.shiftKey) return;
	const direction = event.code === 'KeyZ' ? -1 : event.code === 'KeyX' ? 1 : 0;
	if (!direction) return;
	event.preventDefault();
	shiftOctave(direction);
});

piano.addEventListener('note-down', (event) => post({ type: 'note', note: event.detail.note, on: true }));
piano.addEventListener('note-up', (event) => post({ type: 'note', note: event.detail.note, on: false }));
addEventListener('focus', () => piano.focus({ preventScroll: true }));
addEventListener('blur', () => piano.allNotesOff());

connectWindow(win);
host.addEventListener('state', ({ detail }) => {
	outputLabel.textContent = `· ${detail.outputName}`;
	if (rootNote < 0) setRange(detail.keyboard.root, detail.keyboard.count);
});

piano.focus({ preventScroll: true });
post({ type: 'ready' });
