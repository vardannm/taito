// Verify the generated deliverables, not production gameplay.
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const crypto = require('crypto');

const root = path.resolve(process.argv[2] || 'release/app-store/2026-10-18');
const sizes = {
  'iphone-6-3': [1206, 2622], 'iphone-6-9': [1320, 2868],
  'ipad-13': [2064, 2752], 'duo-outer': [1398, 2034], 'duo-inner': [2853, 2007],
};
const shots = ['01-precision', '02-infinite', '03-classic', '04-boss', '05-merge', '06-gear'];
const checksum = [], images = [];
function fail(message) { throw Error(message); }
function crc32(buffer) {
  let crc = 0xffffffff;
  for (const byte of buffer) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit++) crc = crc & 1 ? (crc >>> 1) ^ 0xedb88320 : crc >>> 1;
  }
  return (crc ^ 0xffffffff) >>> 0;
}
function png(relative, expected) {
  const data = fs.readFileSync(path.join(root, relative));
  if (!data.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10]))) fail(relative + ': invalid PNG');
  const width = data.readUInt32BE(16), height = data.readUInt32BE(20);
  if (width !== expected[0] || height !== expected[1]) fail(relative + ': incorrect dimensions');
  if (data[24] !== 8 || data[25] !== 2) fail(relative + ': must be 8-bit RGB with no alpha channel');
  const compressed = [];
  let ended = false;
  for (let at = 8; at < data.length;) {
    const size = data.readUInt32BE(at), type = data.toString('ascii', at + 4, at + 8);
    if (at + size + 12 > data.length) fail(relative + ': truncated PNG chunk');
    if (crc32(data.subarray(at + 4, at + 8 + size)) !== data.readUInt32BE(at + 8 + size)) fail(relative + ': corrupt PNG checksum');
    if (type === 'tRNS') fail(relative + ': transparency chunk is forbidden');
    if (type === 'IDAT') compressed.push(data.subarray(at + 8, at + 8 + size));
    if (type === 'IEND') ended = true;
    at += size + 12;
  }
  if (!ended) fail(relative + ': missing IEND');
  const pixels = zlib.inflateSync(Buffer.concat(compressed));
  if (pixels.length !== (width * 3 + 1) * height) fail(relative + ': incorrect decoded length');
  for (let y = 0; y < height; y++) if (pixels[y * (width * 3 + 1)] !== 0) fail(relative + ': unexpected row encoding');
  const hash = crypto.createHash('sha256').update(data).digest('hex');
  checksum.push(`${hash}  ${relative}`);
  images.push({file: relative, width, height, pngColorType: 2, bytes: data.length, sha256: hash});
}
for (const [device, size] of Object.entries(sizes)) {
  for (const kind of ['screenshots', 'source-ui']) {
    const files = fs.readdirSync(path.join(root, kind, device)).filter(f => f.endsWith('.png')).sort();
    if (files.join('|') !== shots.map(s => s + '.png').join('|')) fail(`${kind}/${device}: missing or unexpected screenshots`);
    for (const shot of shots) png(`${kind}/${device}/${shot}.png`, size);
  }
}
const limits = {name:30, subtitle:30, promotional_text:170, keywords:100, description:4000, whats_new:4000};
const fields = {};
for (const [key, limit] of Object.entries(limits)) {
  const text = fs.readFileSync(path.join(root, `copy/en-US/${key}.txt`), 'utf8').trimEnd();
  const length = [...text].length;
  if (!length || length > limit) fail(key + ': invalid character count');
  fields[key] = {characters:length, limit};
  if (key === 'keywords') {
    const bytes = Buffer.byteLength(text, 'utf8');
    if (bytes > 100) fail('keywords: exceeds 100 UTF-8 bytes');
    fields[key].utf8Bytes = bytes;
    fields[key].limitUnit = 'bytes';
  }
}
const manifest = JSON.parse(fs.readFileSync(path.join(root, 'manifest.json')));
if (manifest.length !== 30) fail('Expected 30 final screenshot records');
for (const item of manifest) if (!images.some(i => i.file === item.file && i.width === item.width && i.height === item.height)) fail('Manifest mismatch: ' + item.file);
fs.writeFileSync(path.join(root, 'checksums.sha256'), checksum.join('\n') + '\n');
fs.writeFileSync(path.join(root, 'validation.json'), JSON.stringify({
  status:'passed', date:'2026-10-18', screenshotCount:30, sourceCaptureCount:30,
  checks:['exact Apple display dimensions','RGB PNG without alpha or tRNS','valid PNG CRCs','complete decoded pixels','six screenshots per display','metadata character limits'],
  fields, images,
}, null, 2) + '\n');
console.log('PASS: 30 store images + 30 source UI renders; exact dimensions, RGB/no alpha, PNG integrity, metadata limits.');
