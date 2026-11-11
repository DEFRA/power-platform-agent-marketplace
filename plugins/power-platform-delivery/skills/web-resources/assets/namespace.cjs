// The one place that maps a bundle's file name to its global namespace.
// 'contact.ribbon.js' becomes 'Contact.Ribbon': each dot-separated segment is PascalCased.
// Shared by rollup.config.mjs and tests/bundle.contract.test.ts.
function namespaceFor(fileName) {
  return fileName
    .replace(/\.(ts|js)$/, '')
    .split('.')
    .map((segment) => segment.charAt(0).toUpperCase() + segment.slice(1))
    .join('.');
}

module.exports = { namespaceFor };
