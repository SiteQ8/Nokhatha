// Line icons on a 24 grid, stroke 1.75, drawn for Nokhatha.
// Colour comes from currentColor so every icon follows the text around it.

const P = {
  today: '<circle cx="12" cy="12" r="8.5"/><circle cx="12" cy="3.5" r="2" class="fill"/>',
  home: '<path d="M4 11.5 12 5l8 6.5"/><path d="M6 10v9.5h12V10"/><path d="M10 19.5V14h4v5.5"/>',
  car: '<path d="M3.5 16h17v-3.2a2 2 0 0 0-.6-1.4L18 9.5l-1.6-3.2A2 2 0 0 0 14.6 5H9.4a2 2 0 0 0-1.8 1.3L6 9.5l-1.9 1.9a2 2 0 0 0-.6 1.4Z"/><path d="M6 9.5h12M5.5 16v2.5M18.5 16v2.5"/><circle cx="7.5" cy="12.8" r="1" class="fill"/><circle cx="16.5" cy="12.8" r="1" class="fill"/>',
  repeat: '<path d="M4 12a8 8 0 0 1 13.7-5.6L20 8.5"/><path d="M20 4v4.5h-4.5"/><path d="M20 12a8 8 0 0 1-13.7 5.6L4 15.5"/><path d="M4 20v-4.5h4.5"/>',
  more: '<circle cx="5.5" cy="12" r="1.4" class="fill"/><circle cx="12" cy="12" r="1.4" class="fill"/><circle cx="18.5" cy="12" r="1.4" class="fill"/>',
  filter: '<rect x="4" y="5" width="16" height="14" rx="2"/><path d="M4 9.7h16M4 14.3h16M9.3 5v14M14.7 5v14"/>',
  ac: '<rect x="3" y="5" width="18" height="8" rx="2"/><path d="M6.5 10h11"/><path d="M8 16.5c.8.8.8 1.7 0 2.5M12 16.5c.8.8.8 1.7 0 2.5M16 16.5c.8.8.8 1.7 0 2.5"/>',
  duct: '<path d="M3 8h12a3 3 0 0 1 3 3v9"/><path d="M3 12h9a2 2 0 0 1 2 2v6"/><path d="M3 8v4M14 20h4"/>',
  tank: '<ellipse cx="12" cy="6" rx="7" ry="2.5"/><path d="M5 6v9c0 1.4 3.1 2.5 7 2.5s7-1.1 7-2.5V6"/><path d="M8 17.2V21M16 17.2V21"/>',
  drop: '<path d="M12 3.5c3.5 4.2 5.5 7.3 5.5 10a5.5 5.5 0 0 1-11 0c0-2.7 2-5.8 5.5-10Z"/><path d="M9.5 14a2.5 2.5 0 0 0 2.5 2.5"/>',
  heater: '<rect x="6.5" y="3" width="11" height="15" rx="5.5"/><path d="M12 7.5c1.4 1.5 1.8 2.5 1.8 3.3a1.8 1.8 0 0 1-3.6 0c0-.8.4-1.8 1.8-3.3Z"/><path d="M9 21h6M12 18v3"/>',
  leak: '<path d="M12 3.5c3.5 4.2 5.5 7.3 5.5 10a5.5 5.5 0 0 1-11 0c0-2.7 2-5.8 5.5-10Z"/><path d="m11 9.5 2 2-2 2 2 2"/>',
  roof: '<path d="M3 11.5 12 4.5l9 7"/><path d="M6 10v9h8"/><path d="M18 10v6.5"/><circle cx="18" cy="19.6" r=".9" class="fill"/>',
  window: '<rect x="5" y="3.5" width="14" height="17" rx="1.5"/><path d="M12 3.5v17M5 12h14"/>',
  smoke: '<circle cx="12" cy="8.5" r="5"/><circle cx="12" cy="8.5" r="1.2" class="fill"/><path d="M7.5 17c1-1 2-1 3 0s2 1 3 0 2-1 3 0"/><path d="M6 20.5c1-1 2-1 3 0s2 1 3 0 2-1 3 0 2-1 3 0"/>',
  extinguisher: '<rect x="8" y="8" width="7" height="13" rx="1.2"/><path d="M11.5 8V5.5M9.5 5.5h4l3-1.5M8 12.5h7"/>',
  gas: '<path d="M8 7h8a2 2 0 0 1 2 2v9a3 3 0 0 1-3 3H9a3 3 0 0 1-3-3V9a2 2 0 0 1 2-2Z"/><path d="M10 7V4.5h4V7M6 12h12"/>',
  hood: '<path d="M9 3.5h6v4H9Z"/><path d="M9 7.5 4 13h16l-5-5.5"/><path d="M4 13v2h16v-2"/><path d="M9 18.5v1M12 18.5v2M15 18.5v1"/>',
  bug: '<ellipse cx="12" cy="13.5" rx="4.5" ry="6"/><path d="M12 7.5v12M9.5 6a2.5 2.5 0 0 1 5 0"/><path d="M7.5 11 4 9.5M16.5 11 20 9.5M7.5 15H4M16.5 15H20M7.8 18l-3 2M16.2 18l3 2"/>',
  bolt: '<path d="M13 3 5.5 13.5H12L11 21l7.5-10.5H12Z"/>',
  oil: '<path d="M4 10h9l4-3 3.5 1.5-5 5.5a2 2 0 0 1-1.5.7H6a2 2 0 0 1-2-2Z"/><path d="M8 10V7.5h3"/><path d="M20 16.5c.6.9 1 1.6 1 2.1a1 1 0 0 1-2 0c0-.5.4-1.2 1-2.1Z"/>',
  air: '<path d="M3 9h11a2.5 2.5 0 1 0-2.5-2.5"/><path d="M3 13h15a2.5 2.5 0 1 1-2.5 2.5"/><path d="M3 17h7"/>',
  fan: '<circle cx="12" cy="12" r="1.6"/><path d="M12 10.4c-1-3 .5-6 3-6 1.8 0 2.5 2.5.5 4.5M13.6 12c3-1 6 .5 6 3 0 1.8-2.5 2.5-4.5.5M12 13.6c1 3-.5 6-3 6-1.8 0-2.5-2.5-.5-4.5M10.4 12c-3 1-6-.5-6-3 0-1.8 2.5-2.5 4.5-.5"/>',
  snow: '<path d="M12 3v18M4.2 7.5l15.6 9M4.2 16.5l15.6-9"/><path d="m9.5 4.5 2.5 2 2.5-2M9.5 19.5l2.5-2 2.5 2"/>',
  thermo: '<path d="M10 14.5V5a2 2 0 1 1 4 0v9.5a3.5 3.5 0 1 1-4 0Z"/><path d="M12 9v7.5"/>',
  tire: '<circle cx="12" cy="12" r="8.5"/><circle cx="12" cy="12" r="3.5"/><path d="M12 3.5v5M12 15.5v5M3.5 12h5M15.5 12h5"/>',
  gauge: '<path d="M4.5 16.5a8 8 0 1 1 15 0"/><path d="m12 13.5 3.5-4"/><circle cx="12" cy="13.5" r="1.3" class="fill"/>',
  brake: '<circle cx="12" cy="12" r="6.5"/><circle cx="12" cy="12" r="2.3"/><path d="M19.8 8.3a8.5 8.5 0 0 1 0 7.4M4.2 8.3a8.5 8.5 0 0 0 0 7.4"/>',
  battery: '<rect x="3.5" y="7" width="17" height="12" rx="1.5"/><path d="M7 7V5h3v2M14 7V5h3v2M6.8 12.5h3M8.3 11v3M14.5 12.5h3"/>',
  wiper: '<path d="M3.5 17.5a11 11 0 0 1 17 0"/><path d="M12 19 16.5 8"/><circle cx="12" cy="19" r="1.3" class="fill"/>',
  doc: '<path d="M7 3.5h7l4 4V20a.5.5 0 0 1-.5.5h-10.5a.5.5 0 0 1-.5-.5V4a.5.5 0 0 1 .5-.5Z"/><path d="M14 3.5V8h4M9 12h6M9 15.5h6"/>',
  shield: '<path d="M12 3.5 5 6v5.5c0 4.3 2.9 7.6 7 9 4.1-1.4 7-4.7 7-9V6Z"/><path d="m9 12 2.2 2.2L15.5 10"/>',
  check: '<rect x="5.5" y="4.5" width="13" height="16" rx="1.5"/><path d="M9 4.5V3h6v1.5M9 13l2 2 4-4"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  done: '<path d="m5 12.5 4.5 4.5L19 7.5"/>',
  snooze: '<circle cx="12" cy="13" r="7.5"/><path d="M12 9v4l2.5 2M5 4.5 3 6.5M19 4.5l2 2"/>',
  phone: '<path d="M5 4h3.5l1.5 4.5-2.2 1.3a11 11 0 0 0 6.4 6.4l1.3-2.2L20 15.5V19a1 1 0 0 1-1 1A16 16 0 0 1 4 5a1 1 0 0 1 1-1Z"/>',
  chat: '<path d="M20 12a8 8 0 0 1-11.6 7.1L4 20l1.1-4.2A8 8 0 1 1 20 12Z"/><path d="M8.5 10.5h7M8.5 13.5h4.5"/>',
  receipt: '<path d="M6 3.5h12v17l-2-1.3-2 1.3-2-1.3-2 1.3-2-1.3-2 1.3Z"/><path d="M9 8h6M9 11.5h6M9 15h3.5"/>',
  seal: '<circle cx="12" cy="9.5" r="5.5"/><path d="m9 14.3-1.5 6.2 4.5-2.3 4.5 2.3-1.5-6.2"/>',
  plane: '<path d="M10.5 13.5 3.5 11l17-6.5-6.5 17-2.5-7Z"/><path d="m10.5 13.5 4-4"/>',
  wallet: '<path d="M4 7.5a2 2 0 0 1 2-2h11v3"/><rect x="4" y="8.5" width="16" height="11" rx="2"/><path d="M15.5 14h2"/>',
  sliders: '<path d="M4 7h10M18 7h2M4 17h4M12 17h8"/><circle cx="16" cy="7" r="2"/><circle cx="10" cy="17" r="2"/>',
  wrench: '<path d="M14.5 4.5a4.5 4.5 0 0 0-4.3 5.8L4 16.5 7.5 20l6.2-6.2a4.5 4.5 0 0 0 5.8-4.3l-2.7 2.7-2.3-.5-.5-2.3Z"/>',
  trash: '<path d="M4.5 7h15M10 7V4.5h4V7M6.5 7l1 13h9l1-13"/>',
  edit: '<path d="M4 20h4l10.5-10.5a2.1 2.1 0 0 0-3-3L5 17v3Z"/>',
  lock: '<rect x="5" y="10.5" width="14" height="10" rx="2"/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5"/>',
  download: '<path d="M12 4v11M7.5 10.5 12 15l4.5-4.5M5 20h14"/>',
  upload: '<path d="M12 15V4M7.5 8.5 12 4l4.5 4.5M5 20h14"/>',
  calendar: '<rect x="4" y="5.5" width="16" height="14.5" rx="2"/><path d="M4 10h16M8.5 3.5v4M15.5 3.5v4"/>',
  globe: '<circle cx="12" cy="12" r="8.5"/><path d="M3.5 12h17M12 3.5c2.5 2.5 3.5 5.5 3.5 8.5s-1 6-3.5 8.5c-2.5-2.5-3.5-5.5-3.5-8.5s1-6 3.5-8.5Z"/>',
  sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2.5v2M12 19.5v2M2.5 12h2M19.5 12h2M5.3 5.3l1.4 1.4M17.3 17.3l1.4 1.4M5.3 18.7l1.4-1.4M17.3 6.7l1.4-1.4"/>',
  moon: '<path d="M19.5 14.5A8 8 0 0 1 9.5 4.5a8 8 0 1 0 10 10Z"/>',
  info: '<circle cx="12" cy="12" r="8.5"/><path d="M12 11v5.5M12 7.8v.01"/>',
  next: '<path d="m9.5 6 6 6-6 6"/>',
  back: '<path d="m14.5 6-6 6 6 6"/>',
  close: '<path d="M6 6l12 12M18 6 6 18"/>',
  spark: '<path d="M12 3.5 13.8 10 20.5 12l-6.7 2L12 20.5 10.2 14 3.5 12l6.7-2Z"/>',
  code: '<path d="m8.5 7.5-5 4.5 5 4.5M15.5 7.5l5 4.5-5 4.5M13.5 5l-3 14"/>',
  camera: '<path d="M4 8.5a1.5 1.5 0 0 1 1.5-1.5h2.5l1.5-2h5l1.5 2h2.5A1.5 1.5 0 0 1 20 8.5v9a1.5 1.5 0 0 1-1.5 1.5h-13A1.5 1.5 0 0 1 4 17.5Z"/><circle cx="12" cy="12.5" r="3.5"/>',
  play: '<circle cx="12" cy="12" r="8.5"/><path d="M10.2 8.8v6.4l5-3.2Z"/>',
  music: '<path d="M9 17.5V6.5l10-2v11"/><circle cx="6.8" cy="17.5" r="2.2"/><circle cx="16.8" cy="15.5" r="2.2"/>',
  cloud: '<path d="M7 18.5a4 4 0 0 1-.5-8 5.5 5.5 0 0 1 10.6-1.3A4.3 4.3 0 0 1 17.5 18.5Z"/>',
  game: '<path d="M7 8h10a4 4 0 0 1 3.9 4.8l-.7 3.5a2 2 0 0 1-3.4 1L14.5 15h-5l-2.3 2.3a2 2 0 0 1-3.4-1l-.7-3.5A4 4 0 0 1 7 8Z"/><path d="M8 10.5v3M6.5 12h3"/><circle cx="15.5" cy="11.3" r=".8" class="fill"/><circle cx="17.2" cy="13" r=".8" class="fill"/>',
  gym: '<path d="M6.5 8v8M17.5 8v8M4 10v4M20 10v4M6.5 12h11"/>',
  wifi: '<path d="M3.5 9.5a12 12 0 0 1 17 0M6.5 12.8a7.5 7.5 0 0 1 11 0M9.5 16a3 3 0 0 1 5 0"/><circle cx="12" cy="18.8" r="1" class="fill"/>',
  apps: '<rect x="4" y="4" width="6.5" height="6.5" rx="1.5"/><rect x="13.5" y="4" width="6.5" height="6.5" rx="1.5"/><rect x="4" y="13.5" width="6.5" height="6.5" rx="1.5"/><rect x="13.5" y="13.5" width="6.5" height="6.5" rx="1.5"/>',
};

export const ICONS = Object.keys(P);

export function icon(name, cls = '') {
  const body = P[name] || P.spark;
  return `<svg class="ic ${cls}" viewBox="0 0 24 24" aria-hidden="true" focusable="false">${body}</svg>`;
}

// The mark: a boom under a lateen sail inside the ring of the year,
// with the pearl of today on the ring and Sadu teeth for the sea.
export const MARK_BODY =
  '<circle class="mk-ring" cx="32" cy="32" r="26.5"/>' +
  '<path class="mk-sail" d="M47.2 30.2C40.6 22.4 31.8 15.2 20.4 10.6c1.9 7.1 3.4 14.3 3.9 21.6Z"/>' +
  '<path class="mk-hull" d="M11.8 35.4 52.6 32.2c-1.7 4.6-4.5 8.3-8.6 10.6-7.9 2.5-17.6 2.7-25.4.7-3.3-1.9-5.6-4.8-6.8-8.1Z"/>' +
  '<path class="mk-sea" d="m15.5 50.2 3.4-3.4 3.4 3.4 3.4-3.4 3.4 3.4 3.4-3.4 3.4 3.4 3.4-3.4 3.4 3.4 3.4-3.4 3.4 3.4"/>' +
  '<circle class="mk-pearl" cx="45.3" cy="9.1" r="4.4"/>';

export function mark(cls = '') {
  return `<svg class="mark ${cls}" viewBox="0 0 64 64" aria-hidden="true" focusable="false">${MARK_BODY}</svg>`;
}
