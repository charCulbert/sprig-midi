import './compost/components/compost-window.js';

const handler = window.webkit?.messageHandlers?.host;

export const clamp = (value, min, max) => Math.min(max, Math.max(min, value));

export function post(message) {
	handler?.postMessage(message);
}

export const kind = location.search.slice(1);
let zoom = 1;

export const host = new EventTarget();
window.host = {
	receive(message) {
		host.dispatchEvent(new CustomEvent(message.type, { detail: message }));
	},
};

host.addEventListener('state', ({ detail }) => {
	document.documentElement.style.colorScheme = detail.theme === 'system' ? 'light dark' : detail.theme;
});

export function connectWindow(win) {
	win.addEventListener('window-close', (event) => {
		event.preventDefault();
		post({ type: 'close' });
	});
	win.addEventListener('window-pin', (event) => {
		post({ type: 'pin', pinned: event.detail.pinned });
	});
	host.addEventListener('state', ({ detail }) => {
		const panel = detail.panels[kind];
		win.alwaysOnTop = panel.pinned;
		zoom = panel.zoom;
	});

	for (const [label, step] of [['−', -1], ['+', 1]]) {
		const button = document.createElement('button');
		button.className = 'tool';
		button.type = 'button';
		button.textContent = label;
		button.title = step < 0 ? 'smaller  ⌘−' : 'bigger  ⌘+';
		button.addEventListener('click', () => post({ type: 'zoom', step }));
		win.querySelector('.hd').append(button);
	}
	addEventListener('keydown', (event) => {
		if (!event.metaKey) return;
		const step = { Equal: 1, Minus: -1, Digit0: 0 }[event.code];
		if (step === undefined) return;
		event.preventDefault();
		post({ type: 'zoom', step });
	});

	const header = win.shadowRoot.querySelector('header');
	let dragging = null;
	header.addEventListener('pointerdown', (event) => {
		if (event.button !== 0) return;
		if (event.composedPath().some((node) => node instanceof HTMLButtonElement)) return;
		event.preventDefault();
		dragging = event.pointerId;
		header.setPointerCapture(event.pointerId);
		post({ type: 'drag', phase: 'start' });
	});
	header.addEventListener('pointermove', (event) => {
		if (event.pointerId === dragging) post({ type: 'drag', phase: 'move' });
	});
	const end = (event) => {
		if (event.pointerId !== dragging) return;
		dragging = null;
		post({ type: 'drag', phase: 'end' });
	};
	header.addEventListener('pointerup', end);
	header.addEventListener('pointercancel', end);
}

// fractional sizes: when zoomed, rounded ones change with the window height
export function chromeSize(win) {
	const outer = win.getBoundingClientRect();
	const inner = win.shadowRoot.querySelector('.content').getBoundingClientRect();
	return { width: outer.width - inner.width, height: outer.height - inner.height };
}

export function addEdgeGrips(win, onDrag) {
	for (const edge of ['l', 'r', 'b']) {
		const grip = document.createElement('div');
		grip.className = `grip ${edge}`;
		grip.setAttribute('aria-hidden', 'true');
		let start = null;
		grip.addEventListener('pointerdown', (event) => {
			if (event.button !== 0) return;
			event.preventDefault();
			event.stopPropagation();
			start = { pointerId: event.pointerId, x: event.screenX, y: event.screenY, width: innerWidth, height: innerHeight };
			grip.setPointerCapture(event.pointerId);
		});
		grip.addEventListener('pointermove', (event) => {
			if (!start || event.pointerId !== start.pointerId) return;
			onDrag({ edge, dx: (event.screenX - start.x) / zoom, dy: (event.screenY - start.y) / zoom, start });
		});
		const end = (event) => {
			if (start && event.pointerId === start.pointerId) start = null;
		};
		grip.addEventListener('pointerup', end);
		grip.addEventListener('pointercancel', end);
		win.append(grip);
	}
}
