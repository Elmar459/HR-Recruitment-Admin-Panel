import { createElement } from '@lwc/engine-dom';
import MessagingPanel from 'c/messagingPanel';
import getMessages from '@salesforce/apex/RecruitmentLwcController.getMessages';
import sendMessage from '@salesforce/apex/RecruitmentLwcController.sendMessage';

jest.mock(
    '@salesforce/apex/RecruitmentLwcController.getMessages',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return {
            default: createApexTestWireAdapter(jest.fn())
        };
    },
    { virtual: true }
);

jest.mock(
    '@salesforce/apex/RecruitmentLwcController.sendMessage',
    () => ({
        default: jest.fn()
    }),
    { virtual: true }
);

jest.mock(
    'lightning/empApi',
    () => ({
        subscribe: jest.fn(() => Promise.resolve({ id: 'subscription' })),
        unsubscribe: jest.fn(),
        onError: jest.fn()
    }),
    { virtual: true }
);

const flushPromises = () => new Promise((resolve) => setTimeout(resolve, 0));

describe('c-messaging-panel', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('renders messages and sends a draft', async () => {
        sendMessage.mockResolvedValue({
            id: 'msg2',
            body: 'Follow-up sent',
            direction: 'Outbound',
            createdByName: 'Recruiter'
        });

        const element = createElement('c-messaging-panel', {
            is: MessagingPanel
        });
        element.recordId = 'a01xx0000000001';
        document.body.appendChild(element);

        getMessages.emit([
            {
                id: 'msg1',
                body: 'Welcome to the process',
                direction: 'Outbound',
                createdByName: 'Recruiter',
                createdDate: '2026-05-22T10:00:00.000Z'
            }
        ]);
        await flushPromises();

        expect(element.shadowRoot.textContent).toContain('Welcome to the process');

        const textarea = element.shadowRoot.querySelector('lightning-textarea');
        textarea.value = 'Follow-up sent';
        textarea.dispatchEvent(new CustomEvent('change'));
        element.shadowRoot.querySelector('lightning-button-icon').click();
        await flushPromises();

        expect(sendMessage).toHaveBeenCalledWith({
            applicationId: 'a01xx0000000001',
            body: 'Follow-up sent'
        });
    });
});
