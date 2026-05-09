// app/mono/backend/eslint.config.js
const js = require('@eslint/js');
const globals = require('globals');

module.exports = [
  // 1. Recommended rules từ ESLint
  js.configs.recommended,

  // 2. Config cho các file Node.js (.js trong src/)
  {
    files: ['src/**/*.js'],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: 'commonjs',  // backend dùng require()
      globals: {
        ...globals.node,        // process, __dirname, ...
      },
    },
    rules: {
      // Disallow unused variables (trừ tham số bắt đầu bằng _)
      'no-unused-vars': ['error', { argsIgnorePattern: '^_' }],

      // Force === thay vì ==
      'eqeqeq': ['error', 'always'],

      // Cảnh báo console.log (nên dùng logger)
      'no-console': 'warn',

      // Không cho phép var, dùng let/const
      'no-var': 'error',
      'prefer-const': 'error',
    },
  },

  // 3. Config cho test files (cho phép Jest globals)
  {
    files: ['src/**/*.test.js', 'tests/**/*.js'],
    languageOptions: {
      globals: {
        ...globals.jest,  // describe, it, expect, ...
      },
    },
  },

  // 4. Ignore một số file/folder
  {
    ignores: ['node_modules/**', 'coverage/**', 'dist/**'],
  },
];