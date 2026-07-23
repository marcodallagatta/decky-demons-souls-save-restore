import deckyPlugin from "@decky/rollup";

const config = deckyPlugin({});

// The release archive is a runnable plugin, not a debugging artifact.  Keeping
// source maps out avoids publishing local source paths and makes the download
// substantially smaller.
config.output.sourcemap = false;

export default config;
