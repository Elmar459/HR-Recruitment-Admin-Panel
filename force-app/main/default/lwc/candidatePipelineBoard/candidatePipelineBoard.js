import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import getPipelineBoard from '@salesforce/apex/RecruitmentLwcController.getPipelineBoard';
import updateApplicationStatus from '@salesforce/apex/RecruitmentLwcController.updateApplicationStatus';

const PIPELINE_CHANNEL = '/event/Application_Pipeline_Update__e';

export default class CandidatePipelineBoard extends LightningElement {
    searchTerm = '';
    draggedApplicationId;
    wiredBoard;
    stages = [];
    isBusy = false;
    errorMessage;
    subscription;

    connectedCallback() {
        onError(() => {});
        this.subscribeToPipelineUpdates();
    }

    disconnectedCallback() {
        if (this.subscription) {
            unsubscribe(this.subscription, () => {});
        }
    }

    @wire(getPipelineBoard)
    loadBoard(result) {
        this.wiredBoard = result;
        if (result.data) {
            this.stages = result.data;
            this.errorMessage = undefined;
        } else if (result.error) {
            this.errorMessage = this.reduceError(result.error);
        }
    }

    get visibleStages() {
        const term = this.searchTerm.trim().toLowerCase();
        return (this.stages || []).map((stage) => {
            const applications = (stage.applications || [])
                .filter((app) => this.matchesSearch(app, term))
                .map((app) => this.decorateApplication(app));

            return {
                ...stage,
                applications,
                count: applications.length,
                isEmpty: applications.length === 0
            };
        });
    }

    handleSearch(event) {
        this.searchTerm = event.target.value || '';
    }

    handleDragStart(event) {
        this.draggedApplicationId = event.currentTarget.dataset.id;
        event.dataTransfer.effectAllowed = 'move';
    }

    handleDragOver(event) {
        event.preventDefault();
        event.dataTransfer.dropEffect = 'move';
    }

    async handleDrop(event) {
        event.preventDefault();
        const status = event.currentTarget.dataset.status;
        if (!this.draggedApplicationId || !status) {
            return;
        }

        this.isBusy = true;
        try {
            await updateApplicationStatus({
                applicationId: this.draggedApplicationId,
                newStatus: status
            });
            await refreshApex(this.wiredBoard);
            this.showToast('Pipeline updated', `Application moved to ${status}.`, 'success');
        } catch (error) {
            this.showToast('Could not update pipeline', this.reduceError(error), 'error');
        } finally {
            this.isBusy = false;
            this.draggedApplicationId = undefined;
        }
    }

    async handleRefresh() {
        this.isBusy = true;
        try {
            await refreshApex(this.wiredBoard);
        } finally {
            this.isBusy = false;
        }
    }

    async subscribeToPipelineUpdates() {
        try {
            this.subscription = await subscribe(PIPELINE_CHANNEL, -1, async () => {
                if (this.wiredBoard) {
                    await refreshApex(this.wiredBoard);
                }
            });
        } catch (error) {
            this.subscription = undefined;
        }
    }

    decorateApplication(app) {
        const score = app.matchScore === null || app.matchScore === undefined ? null : Math.round(app.matchScore);
        return {
            ...app,
            candidateName: app.candidateName || 'Unnamed candidate',
            positionName: app.positionName || 'No position',
            matchLabel: score === null ? 'No score' : `${score}%`,
            daysLabel: app.daysInStage ? `${app.daysInStage}d in stage` : 'New stage',
            priorityLabel: app.priority ? `${app.priority} priority` : 'Normal priority',
            cardClass: app.slaBreached ? 'application-card application-card_breached' : 'application-card'
        };
    }

    matchesSearch(app, term) {
        if (!term) {
            return true;
        }
        return [app.candidateName, app.positionName, app.status, app.priority]
            .filter(Boolean)
            .some((value) => value.toLowerCase().includes(term));
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
