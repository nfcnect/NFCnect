import {readFileSync,writeFileSync} from 'node:fs';
const configuration=readFileSync('docs/CONFIGURATION.md','utf8'),verification=readFileSync('docs/VERIFICATION.md','utf8');
writeFileSync('server/documents.mjs','export const configuration='+JSON.stringify(configuration)+';\nexport const verification='+JSON.stringify(verification)+';\n');
