import './compost/components/compost-knob.js';
import './compost/components/compost-slider.js';
import { createParameterController } from './compost/parameter-controller.js';
import { addEdgeGrips, chromeSize, clamp, connectWindow, host, kind, post } from './panel.js';

const MAX_COLUMNS = 16;
const MIN_HEIGHT = 110;
const MAX_HEIGHT = 900;

const win = document.querySelector('compost-window');
const bank = document.querySelector('.bank');
const outputLabel = document.querySelector('#output');
const channelLabel = document.querySelector('#channel');
const parameters = createParameterController({ root: bank });
const sent = new Map();
let columns = 0;
let specsKey = '';
let specs = [];

document.body.dataset.layout = kind;
document.querySelector('.hd b').textContent = kind === 'knobs' ? 'Knobs' : 'Sliders';

const columnWidth = () => parseFloat(getComputedStyle(bank).getPropertyValue('--column'));
const bankPadding = () => {
	const style = getComputedStyle(bank);
	return parseFloat(style.paddingLeft) + parseFloat(style.paddingRight);
};

function control(tag, spec, attributes) {
	const element = document.createElement(tag);
	for (const [name, value] of Object.entries({
		'parameter-id': spec.id,
		label: spec.label,
		min: 0,
		max: 127,
		step: 1,
		'reset-value': 0,
		'display-fraction-digits': 0,
		value: spec.value,
		...attributes,
	})) {
		element.setAttribute(name, String(value));
	}
	return element;
}

function ccLabel(spec) {
	const label = document.createElement('span');
	label.className = 'cc';
	label.textContent = `cc ${spec.cc}`;
	return label;
}

function render() {
	bank.replaceChildren(...specs.slice(0, columns).map((spec) => {
		const strip = document.createElement('div');
		strip.className = 'strip';
		if (kind === 'knobs') {
			strip.append(control('compost-knob', spec, {}), ccLabel(spec));
		} else {
			const slot = document.createElement('div');
			slot.className = 'slot';
			slot.append(control('compost-slider', spec, { orientation: 'vertical' }));
			strip.append(slot, ccLabel(spec));
		}
		return strip;
	}));
	parameters.refresh();
	slotObserver.disconnect();
	const slot = bank.querySelector('.slot');
	if (slot) slotObserver.observe(slot);
}

function fitSliders() {
	const slot = bank.querySelector('.slot');
	const slider = slot?.firstElementChild;
	const track = slider?.shadowRoot?.querySelector('.range-input');
	if (!track) return;
	const rows = slider.offsetHeight - track.offsetHeight;
	bank.style.setProperty('--length', `${Math.max(24, slot.clientHeight - rows)}px`);
}
const slotObserver = new ResizeObserver(fitSliders);
document.fonts.ready.then(() => {
	fitSliders();
	if (kind === 'knobs') setColumns(columns);
});

function setColumns(count, { anchor = 'left', height = innerHeight } = {}) {
	count = clamp(Math.round(count), 1, MAX_COLUMNS);
	if (count !== columns) {
		columns = count;
		render();
		post({ type: 'columns', count });
	}
	const chrome = chromeSize(win);
	const width = count * columnWidth() + bankPadding() + chrome.width;
	height = kind === 'knobs' ? bank.offsetHeight + chrome.height : clamp(height, MIN_HEIGHT, MAX_HEIGHT);
	post({ type: 'resize', width, height, anchor });
}

addEdgeGrips(win, ({ edge, dx, dy, start }) => {
	start.columns ??= columns;
	if (edge === 'b') {
		setColumns(columns, { height: start.height + dy });
		return;
	}
	const delta = Math.round((edge === 'r' ? dx : -dx) / columnWidth());
	setColumns(start.columns + delta, { anchor: edge === 'r' ? 'left' : 'right' });
});

parameters.addEventListener('parameter-edit', ({ detail }) => {
	const value = Math.round(detail.value);
	if (sent.get(detail.parameterID) === value) return;
	sent.set(detail.parameterID, value);
	post({ type: 'cc', id: detail.parameterID, value });
});

bank.addEventListener('contextmenu', (event) => {
	const target = event.composedPath().find((node) => node instanceof Element && node.hasAttribute('parameter-id'));
	if (!target) return;
	event.preventDefault();
	post({ type: 'context', id: target.getAttribute('parameter-id') });
});

connectWindow(win);
host.addEventListener('state', ({ detail }) => {
	outputLabel.textContent = `· ${detail.outputName}`;
	channelLabel.textContent = `ch ${detail.channel}`;
	specs = detail[kind];
	const key = JSON.stringify(specs.map(({ label, cc }) => [label, cc]));
	if (key !== specsKey || columns === 0) {
		specsKey = key;
		columns = 0;
		setColumns(detail.panels[kind].columns);
	}
});

post({ type: 'ready' });
