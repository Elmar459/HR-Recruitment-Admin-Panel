import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import getMessages from '@salesforce/apex/RecruitmentLwcController.getMessages';
import sendMessage from '@salesforce/apex/RecruitmentLwcController.sendMessage';
import getChatterPosts from '@salesforce/apex/RecruitmentLwcController.getChatterPosts';
import postToChatter from '@salesforce/apex/RecruitmentLwcController.postToChatter';
import markAllMessagesRead from '@salesforce/apex/RecruitmentLwcController.markAllMessagesRead';
import publishTypingIndicator from '@salesforce/apex/RecruitmentLwcController.publishTypingIndicator';

const EVENT_CHANNEL = '/event/Recruitment_Message__e';
const POLLING_INTERVAL_MS = 5000;
const TYPING_CLEAR_MS = 2500;

export default class MessagingPanel extends LightningElement {
    @api recordId;
    draft = '';
    chatterDraft = '';
    selectedChannel = 'Portal';
    directionFilter = 'All';
    channelFilter = 'All';
    messages = [];
    chatterPosts = [];
    wiredMessages;
    wiredChatter;
    subscription;
    pollingId;
    typingTimer;
    isSending = false;
    isPosting = false;
    isTyping = false;
    isRealtimeConnected = false;

    channelOptions = [
        { label: 'Portal', value: 'Portal' },
        { label: 'Email', value: 'Email' }
    ];

    directionOptions = [
        { label: 'All', value: 'All' },
        { label: 'Inbound', value: 'Inbound' },
        { label: 'Outbound', value: 'Outbound' }
    ];

    channelFilterOptions = [
        { label: 'All Channels', value: 'All' },
        { label: 'Email', value: 'Email' },
        { label: 'Portal', value: 'Portal' },
        { label: 'Chatter', value: 'Chatter' }
    ];

    @wire(getMessages, { applicationId: '$recordId' })
    loadMessages(result) {
        this.wiredMessages = result;
        if (result.data) {
            this.messages = result.data;
        }
    }

    @wire(getChatterPosts, { applicationId: '$recordId' })
    loadChatter(result) {
        this.wiredChatter = result;
        if (result.data) {
            this.chatterPosts = result.data;
        }
    }

    connectedCallback() {
        onError(() => {
            this.startPolling();
        });
        this.subscribeToMessages();
    }

    disconnectedCallback() {
        if (this.subscription) {
            unsubscribe(this.subscription, () => {});
        }
        this.stopPolling();
        window.clearTimeout(this.typingTimer);
    }

    get decoratedMessages() {
        return (this.messages || [])
            .filter((message) => this.matchesFilters(message))
            .map((message, index) => {
                const direction = message.direction || 'Outbound';
                const channel = message.channel || 'Portal';
                const sender = message.senderName || message.createdByName || direction;
                return {
                    ...message,
                    key: message.id || `${direction}-${index}-${message.body}`,
                    messageClass: direction === 'Inbound' ? 'mp-message mp-message_inbound' : 'mp-message mp-message_outbound',
                    channelIcon: this.channelIcon(channel),
                    sender,
                    createdLabel: this.formatDate(message.createdDate),
                    unreadClass: message.isRead === false ? 'mp-unread-dot' : 'mp-unread-dot mp-unread-dot_read'
                };
            });
    }

    get decoratedChatterPosts() {
        return (this.chatterPosts || []).map((post) => ({
            ...post,
            createdLabel: this.formatDate(post.createdDate),
            author: post.createdByName || 'Salesforce'
        }));
    }

    get unreadCount() {
        return (this.messages || []).filter((message) => message.isRead === false).length;
    }

    get unreadLabel() {
        return `${this.unreadCount} unread`;
    }

    get connectionLabel() {
        return this.isRealtimeConnected ? 'Real-time' : 'Polling fallback';
    }

    get isEmpty() {
        return this.decoratedMessages.length === 0;
    }

    get isChatterEmpty() {
        return this.decoratedChatterPosts.length === 0;
    }

    get sendDisabled() {
        return this.isSending || !this.draft.trim();
    }

    get postDisabled() {
        return this.isPosting || !this.chatterDraft.trim();
    }

    handleDraftChange(event) {
        this.draft = event.target.value;
        this.publishTyping(true);
    }

    handleChatterDraftChange(event) {
        this.chatterDraft = event.target.value;
    }

    handleChannelChange(event) {
        this.selectedChannel = event.detail.value;
    }

    handleDirectionFilterChange(event) {
        this.directionFilter = event.detail.value;
    }

    handleChannelFilterChange(event) {
        this.channelFilter = event.detail.value;
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
                body,
                channel: this.selectedChannel
            });
            this.upsertMessage(message);
            this.draft = '';
            this.publishTyping(false);
            await refreshApex(this.wiredMessages);
        } catch (error) {
            this.showToast('Could not send message', this.reduceError(error), 'error');
        } finally {
            this.isSending = false;
        }
    }

    async handlePostToChatter() {
        const body = this.chatterDraft.trim();
        if (!body) {
            return;
        }
        this.isPosting = true;
        try {
            const post = await postToChatter({ applicationId: this.recordId, body });
            this.chatterPosts = [post, ...this.chatterPosts];
            this.chatterDraft = '';
            await refreshApex(this.wiredChatter);
        } catch (error) {
            this.showToast('Could not post to Chatter', this.reduceError(error), 'error');
        } finally {
            this.isPosting = false;
        }
    }

    async handleMarkAllRead() {
        try {
            await markAllMessagesRead({ applicationId: this.recordId });
            this.messages = this.messages.map((message) => ({ ...message, isRead: true }));
            await refreshApex(this.wiredMessages);
        } catch (error) {
            this.showToast('Could not mark messages read', this.reduceError(error), 'error');
        }
    }

    async subscribeToMessages() {
        try {
            this.subscription = await subscribe(EVENT_CHANNEL, -1, (event) => {
                this.isRealtimeConnected = true;
                this.stopPolling();
                this.handleMessageEvent(event.data.payload);
            });
        } catch (error) {
            this.isRealtimeConnected = false;
            this.startPolling();
        }
    }

    handleMessageEvent(payload) {
        if (payload.Application_Id__c !== this.recordId) {
            return;
        }

        if (payload.Is_Typing__c) {
            this.isTyping = true;
            window.clearTimeout(this.typingTimer);
            this.typingTimer = window.setTimeout(() => {
                this.isTyping = false;
            }, TYPING_CLEAR_MS);
            return;
        }

        this.isTyping = false;
        if (!payload.Message_Body__c) {
            return;
        }

        this.upsertMessage({
            applicationId: this.recordId,
            body: payload.Message_Body__c,
            direction: payload.Direction__c || 'Inbound',
            channel: payload.Channel__c || 'Portal',
            senderName: payload.Sender_Name__c,
            createdDate: new Date().toISOString(),
            isRead: payload.Direction__c === 'Outbound'
        });
    }

    startPolling() {
        if (this.pollingId) {
            return;
        }
        this.pollingId = window.setInterval(async () => {
            await refreshApex(this.wiredMessages);
            await refreshApex(this.wiredChatter);
        }, POLLING_INTERVAL_MS);
    }

    stopPolling() {
        if (this.pollingId) {
            window.clearInterval(this.pollingId);
            this.pollingId = undefined;
        }
    }

    publishTyping(isTyping) {
        window.clearTimeout(this.typingTimer);
        publishTypingIndicator({
            applicationId: this.recordId,
            isTyping
        }).catch(() => {});
        if (isTyping) {
            this.typingTimer = window.setTimeout(() => {
                publishTypingIndicator({
                    applicationId: this.recordId,
                    isTyping: false
                }).catch(() => {});
            }, TYPING_CLEAR_MS);
        }
    }

    upsertMessage(message) {
        if (message.id && this.messages.some((item) => item.id === message.id)) {
            this.messages = this.messages.map((item) => item.id === message.id ? message : item);
            return;
        }
        this.messages = [...this.messages, message];
    }

    matchesFilters(message) {
        const direction = message.direction || 'Outbound';
        const channel = message.channel || 'Portal';
        return (this.directionFilter === 'All' || direction === this.directionFilter)
            && (this.channelFilter === 'All' || channel === this.channelFilter);
    }

    channelIcon(channel) {
        if (channel === 'Email') {
            return 'utility:email';
        }
        if (channel === 'Chatter') {
            return 'utility:comments';
        }
        return 'utility:world';
    }

    formatDate(value) {
        return value ? new Intl.DateTimeFormat(undefined, {
            dateStyle: 'short',
            timeStyle: 'short'
        }).format(new Date(value)) : 'Just now';
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
