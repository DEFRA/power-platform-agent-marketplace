'use strict';
// Spike provider for promptfoo. Phase 2 grows this into the specification in docs/testing-plan.md section 7.1.
// With config.replay set, it parses a recorded transcript instead of running Copilot CLI, so no credentials are needed.

const fs = require('node:fs');
const path = require('node:path');
const { parseTranscript } = require('./transcript');

class CopilotCliProvider {
  constructor(options = {}) {
    this.config = options.config || {};
  }

  id() {
    return 'copilot-cli';
  }

  async callApi(prompt, context) {
    const vars = (context && context.vars) || {};
    const replay = vars.replay || this.config.replay;
    if (!replay) {
      return { error: 'Live runs are not implemented in the spike provider yet. Set config.replay.' };
    }
    const text = fs.readFileSync(path.resolve(__dirname, replay), 'utf8');
    const evidence = parseTranscript(text);
    return { output: evidence.output, metadata: evidence };
  }
}

module.exports = CopilotCliProvider;
