const { jestConfig } = require('@salesforce/sfdx-lwc-jest/config');
const setupFilesAfterEnv = jestConfig.setupFilesAfterEnv || [];
setupFilesAfterEnv.push('<rootDir>/jest-sa11y-setup.js');
module.exports = {
    ...jestConfig,
    moduleNameMapper: {
        '^c/(ds.*|navButton|stoMessageInboxItem|communityMessageContainer|stoEndDialogueModal|alertdialog|communityConfirmation|communityExpandablePanel|stoInboxCloseItem)$':
            '<rootDir>/force-app/test/jest-mocks/sharedComponent.js'
    },
    setupFiles: ['jest-canvas-mock'],
    setupFilesAfterEnv,
    testTimeout: 10000
};
