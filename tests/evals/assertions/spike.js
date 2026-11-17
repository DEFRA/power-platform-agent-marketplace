// Reads the provider's metadata to prove an assertion can see the evidence (U5).
module.exports = (output, context) => {
  const metadata = context.providerResponse && context.providerResponse.metadata;
  if (!metadata) return { pass: false, score: 0, reason: 'No metadata on the provider response' };
  const loaded = metadata.skillsLoaded.includes(process.env.SPIKE_EXPECT_SKILL || 'power-platform-standards');
  return { pass: loaded, score: loaded ? 1 : 0, reason: `skillsLoaded: ${JSON.stringify(metadata.skillsLoaded)}` };
};
