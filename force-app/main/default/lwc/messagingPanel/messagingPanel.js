import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import getMessages from '@salesforce/apex/RecruitmentLwcController.getMessages';
import sendMessage from '@salesforce/apex/RecruitmentLwcController.sendMessage';

const CHANNEL = '/event/Recruitment_Message__e';

export default class MessagingPanel extends LightningElement {
    @api recordId;
    draft = '';
    messages = [];
    wiredMessages;
    subscription;
    isSending = false;

    @wire(getMessages, { applicationId: '$recordId' })
    loadMessages(result) {
        this.wiredMessages = result;
        if (result.data) {
            this.messages = result.data;
        }
    }

    connectedCallback() {
        onError(() => {});
        this.subscribeToMessages();
    }

    disconnectedCallback() {
        if (this.subscription) {
            unsubscribe(this.subscription, () => {});
        }
    }

    get decoratedMessages() {
        return (this.messages || []).map((message, index) => {
            const created = message.createdDate ? new Intl.DateTimeFormat(undefined, {
                dateStyle: 'short',
                timeStyle: 'short'
            }).format(new Date(message.createdDate)) : 'Just now';
            const direction = message.direction || 'Outbound';
            return {
                ...message,
                key: message.id || `${direction}-${index}-${message.body}`,
                messageClass: direction === 'Inbound' ? 'message message_inbound' : 'message message_outbound',
                meta: `${message.createdByName || direction} - ${created}`
            };
        });
    }

    get isEmpty() {
        return this.decoratedMessages.length === 0;
    }

    get sendDisabled() {
        return this.isSending || !this.draft.trim();
    }

    handleDraftChange(event) {
        this.draft = event.target.value;
    }

    async handleSend() {
        const body = this.draft.trim();
        if (!body) {
            return;
        }

        this.isSending = true;
        try {
            const message = await sendMessage({
                applicationId: this.recordId,
                body
            });
            this.messages = [...this.messages, message];
            this.draft = '';
            await refreshApex(this.wiredMessages);
        } catch (error) {
            this.showToast('Could not send message', this.reduceError(error), 'error');
        } finally {
            this.isSending = false;
        }
    }

    async subscribeToMessages() {
        try {
            this.subscription = await subscribe(CHANNEL, -1, (event) => {
                const payload = event.data.payload;
                if (payload.Application_Id__c !== this.recordId) {
                    return;
                }
                this.messages = [
                    ...this.messages,
                    {
                        applicationId: this.recordId,
                        body: payload.Message_Body__c,
                        direction: payload.Direction__c,
                        createdDate: new Date().toISOString()
                    }
                ];
            });
        } catch (error) {
            this.subscription = undefined;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((item) => item.message).join(', ');
        }
        return error?.body?.message || error?.message || 'Unexpected error';
    }
}
