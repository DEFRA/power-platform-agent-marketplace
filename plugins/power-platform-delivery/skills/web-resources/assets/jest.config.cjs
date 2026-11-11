module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  transform: {
    '^.+\\.tsx?$': ['ts-jest', { tsconfig: 'tsconfig.jest.json' }],
  },
  modulePathIgnorePatterns: ['/out/'],
  reporters: [
    'default',
    ['jest-junit', { outputDirectory: 'test-results', outputName: 'junit.xml' }],
  ],
  collectCoverage: true,
  collectCoverageFrom: ['src/**/*.ts', '!src/global-types.ts'],
  coverageDirectory: 'coverage',
};
