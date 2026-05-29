const eslintJs = require('@eslint/js');
const jestPlugin = require('eslint-plugin-jest');
const auraConfig = require('@salesforce/eslint-plugin-aura');
const lwcConfig = require('@salesforce/eslint-config-lwc/recommended');
const globals = require('globals');

module.exports = [
    // Aura configuration
    ...auraConfig.configs.recommended,
    ...auraConfig.configs.locker,
    {
        files: ['**/aura/**/*.js']
    },

    // LWC configuration
    lwcConfig,
    {
        files: ['**/lwc/**/*.js']
    },

    // LWC test files configuration with Jest globals
    lwcConfig,
    {
        files: ['**/lwc/**/__tests__/**/*.test.js'],
        rules: {
            '@lwc/lwc/no-unexpected-wire-adapter-usages': 'off'
        },
        languageOptions: {
            globals: {
                ...globals.node,
                ...globals.jest
            }
        }
    },

    // Jest mocks configuration
    eslintJs.configs.recommended,
    {
        files: ['**/jest-mocks/**/*.js'],
        languageOptions: {
            sourceType: 'module',
            ecmaVersion: 'latest',
            globals: {
                ...globals.node,
                ...globals.es2021,
                ...globals.jest
            }
        }
    }
];
