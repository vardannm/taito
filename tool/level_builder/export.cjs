// Local server entry point. The browser sends draft data, never executable code.
const model = require('./model.js');
let input = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => { input += chunk; });
process.stdin.on('end', () => {
  try {
    const draft = model.parseDraft(input);
    const source = model.exportDart(draft);
    process.stdout.write(JSON.stringify({draft, source}));
  } catch (error) {
    process.stderr.write(error.message);
    process.exitCode = 1;
  }
});
