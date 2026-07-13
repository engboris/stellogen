// Web worker: runs the Stellogen interpreter off the main thread, so the
// page stays responsive and diverging programs can be terminated from
// index.html instead of freezing the tab.
importScripts('playground.js');

self.onmessage = (e) => {
  const { id, mode, code } = e.data;
  const result = mode === 'check' ? Stellogen.check(code) : Stellogen.run(code);
  self.postMessage({ id, result });
};
