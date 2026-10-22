// Validate the actual generated Google Play PNGs and record their checksums.
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const crypto = require('crypto');
const root = path.resolve(process.argv[2] || 'release/google-play/2026-10-23');
const sizes = {phone: [1080, 1920], 'tablet-7': [1440, 2560], 'tablet-10': [1800, 3200]};
const shots = ['01-precision', '02-infinite', '03-classic', '04-boss', '05-merge', '06-gear'];
const images = [], checksums = [];
function assert(condition, message) { if (!condition) throw Error(message); }
function crc32(data) {
  let crc = 0xffffffff;
  for (const byte of data) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit++) crc = crc & 1 ? (crc >>> 1) ^ 0xedb88320 : crc >>> 1;
  }
  return (crc ^ 0xffffffff) >>> 0;
}
function inspect(relative, expected) {
  const data = fs.readFileSync(path.join(root, relative));
  assert(data.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])), relative + ': PNG signature');
  const width = data.readUInt32BE(16), height = data.readUInt32BE(20);
  assert(width === expected[0] && height === expected[1], relative + ': dimensions');
  assert(Math.min(width, height) >= 320 && Math.max(width, height) <= 3840, relative + ': Play bounds');
  assert(Math.max(width, height) <= 2 * Math.min(width, height), relative + ': aspect-ratio bound');
  assert(width * 16 === height * 9, relative + ': 9:16 portrait');
  assert(data[24] === 8 && data[25] === 2, relative + ': 24-bit RGB PNG without alpha');
  const compressed = [];
  let ended = false;
  for (let at = 8; at < data.length;) {
    const size = data.readUInt32BE(at), type = data.toString('ascii', at + 4, at + 8);
    assert(at + size + 12 <= data.length, relative + ': complete chunk');
    assert(crc32(data.subarray(at + 4, at + 8 + size)) === data.readUInt32BE(at + 8 + size), relative + ': CRC');
    assert(type !== 'tRNS', relative + ': no transparency chunk');
    if (type === 'IDAT') compressed.push(data.subarray(at + 8, at + 8 + size));
    if (type === 'IEND') ended = true;
    at += size + 12;
  }
  assert(ended, relative + ': complete PNG');
  const pixels = zlib.inflateSync(Buffer.concat(compressed));
  assert(pixels.length === (width * 3 + 1) * height, relative + ': decoded pixels');
  const sha256 = crypto.createHash('sha256').update(data).digest('hex');
  checksums.push(`${sha256}  ${relative}`);
  return {file: relative, width, height, bytes: data.length, sha256};
}
const manifest = JSON.parse(fs.readFileSync(path.join(root, 'manifest.json'), 'utf8'));
assert(manifest.length === 18, 'Expected 18 screenshot records');
for (const [device, size] of Object.entries(sizes)) {
  const filenames = fs.readdirSync(path.join(root, 'screenshots', device)).filter(f => f.endsWith('.png')).sort();
  assert(filenames.join('|') === shots.map(s => s + '.png').join('|'), device + ': exactly six ordered screenshots');
  for (const shot of shots) {
    const file = `screenshots/${device}/${shot}.png`;
    const image = inspect(file, size), source = inspect(`source-ui/${device}/${shot}.png`, size);
    assert(image.sha256 === source.sha256, file + ': unaltered app UI capture');
    assert(manifest.some(m => m.file === file && m.width === size[0] && m.height === size[1] && m.capture.includes('Android')), file + ': manifest provenance');
    images.push(image);
  }
}
fs.writeFileSync(path.join(root, 'checksums.sha256'), checksums.join('\n') + '\n');
fs.writeFileSync(path.join(root, 'validation.json'), JSON.stringify({
  status: 'passed', date: '2026-10-23', screenshotCount: images.length,
  checks: ['six screenshots per device', 'exact 9:16 dimensions', 'Google Play size bounds', '24-bit RGB/no alpha', 'PNG chunk CRC and decoded pixels', 'unaltered Android UI captures', 'manifest provenance'],
  images,
}, null, 2) + '\n');
console.log('PASS: 18 Google Play screenshots; dimensions, PNG integrity, RGB/no alpha and capture provenance.');
