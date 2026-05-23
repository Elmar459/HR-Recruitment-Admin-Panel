import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import getPipelineBoard from '@salesforce/apex/RecruitmentLwcController.getPipelineBoard';
import updateApplicationStatus from '@salesforce/apex/RecruitmentLwcController.updateApplicationStatus';
import getFilterOptions from '@salesforce/apex/RecruitmentLwcController.getFilterOptions';
import bulkUpdateApplications from '@salesforce/apex/RecruitmentLwcController.bulkUpdateApplications';

const PIPELINE_CHANNEL = '/event/Application_Pipeline_Update__e';

export default class CandidatePipelineBoard extends LightningElement {
    searchTerm = '';
    draggedApplicationId;
    wiredBoard;
    stages = [];
    isBusy = false;
    errorMessage;
    subscription;
    
    // Filters
    showFilters = false;
    departmentFilter = '';
    recruiterFilter = '';
    positionFilter = '';
    dateFromFilter = '';
    dateToFilter = '';
    slaStatusFilter = 'All';
    showTopMatches = false;
    sortByScore = false;

    // Bulk actions
    selectedApplicationIds = new Set();
    showBulkModal = false;
    bulkAction = null;
    departmentOptions = [];
    recruiterOptions = [];
    positionOptions = [];

    slaStatusOptions = [
        { label: 'All', value: 'All' },
        { label: 'Breached', value: 'Breached' },
        { label: 'At Risk', value: 'At Risk' }
    ];

    connectedCallback() {
        onError(() => {});
        this.subscribeToPipelineUpdates();
        this.loadFilterOptions();
        this.refreshBoard();
    }

    async refreshBoard() {
        try {
            this.isBusy = true;
            const result = await getPipelineBoard();
            console.log('Pipeline board data received:', result);
            console.log('Type:', typeof result);
            console.log('Is Array:', Array.isArray(result));
            
            if (Array.isArray(result) && result.length > 0) {
                console.log('Data is valid array with ' + result.length + ' stages');
                this.stages = result;
            } else {
                console.warn('Data is empty or invalid, using defaults');
                this.stages = this.getDefaultStages();
            }
            this.errorMessage = undefined;
        } catch (error) {
            console.error('Error loading board:', error);
            this.errorMessage = 'Error loading pipeline: ' + this.reduceError(error);
            this.stages = this.getDefaultStages();
        } finally {
            this.isBusy = false;
        }
    }

    handleRefresh() {
        this.refreshBoard();
        this.refreshApex();
    }

    refreshApex() {
        if (this.wiredBoard) {
            refreshApex(this.wiredBoard);
        }
    }

    getDefaultStages() {
        const defaultStatuses = ['New', 'Screening', 'Interview 1', 'Interview 2', 'Interview 3', 'Offer', 'Hired', 'Rejected', 'Withdrawn'];
        return defaultStatuses.map(status => ({
            name: status,
            applications: [],
            count: 0,
            isEmpty: true
        }));
    }

    async loadFilterOptions() {
        try {
            const options = await getFilterOptions();
            const allOption = [{ label: 'All', value: '' }];
            this.departmentOptions = [...allOption, ...(options.departments || [])];
            this.recruiterOptions = [...allOption, ...(options.recruiters || [])];
            this.positionOptions = [...allOption, ...(options.positions || [])];
        } catch (error) {
            console.error('Error loading filter options:', error);
        }
    }

    get visibleStages() {
        const term = this.searchTerm.trim().toLowerCase();
        return (this.stages || []).map((stage) => {
            let applications = (stage.applications || [])
                .filter((app) => this.matchesSearch(app, term))
                .filter((app) => this.matchesFilters(app))
                .map((app) => this.decorateApplication(app));

            if (this.sortByScore) {
                applications.sort((a, b) => (b.matchScore || 0) - (a.matchScore || 0));
            }

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

    handleToggleFilters() {
        this.showFilters = !this.showFilters;
    }

    handleDepartmentFilterChange(event) {
        this.departmentFilter = event.detail.value;
    }

    handleRecruiterFilterChange(event) {
        this.recruiterFilter = event.detail.value;
    }

    handlePositionFilterChange(event) {
        this.positionFilter = event.detail.value;
    }

    handleDateFromFilterChange(event) {
        this.dateFromFilter = event.target.value;
    }

    handleDateToFilterChange(event) {
        this.dateToFilter = event.target.value;
    }

    handleSlaStatusFilterChange(event) {
        this.slaStatusFilter = event.detail.value;
    }

    handleTopMatchesToggle(event) {
        this.showTopMatches = event.target.checked;
    }

    handleSortByScoreToggle(event) {
        this.sortByScore = event.target.checked;
    }

    handleCardSelect(event) {
        const appId = event.currentTarget.dataset.id;
        if (this.selectedApplicationIds.has(appId)) {
            this.selectedApplicationIds.delete(appId);
        } else {
            this.selectedApplicationIds.add(appId);
        }
        this.template.querySelectorAll('article[data-id]').forEach((card) => {
            const isSelected = this.selectedApplicationIds.has(card.dataset.id);
            card.classList.toggle('application-card_selected', isSelected);
        });
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

    handleMassReject() {
        if (this.selectedApplicationIds.size === 0) {
            this.showToast('No applications selected', 'Select at least one application', 'warning');
            return;
        }
        this.bulkAction = 'reject';
        this.showBulkModal = true;
    }

    handleMassAdvance() {
        if (this.selectedApplicationIds.size === 0) {
            this.showToast('No applications selected', 'Select at least one application', 'warning');
            return;
        }
        this.bulkAction = 'advance';
        this.showBulkModal = true;
    }

    async handleBulkConfirm() {
        this.isBusy = true;
        this.showBulkModal = false;
        const count = this.selectedApplicationIds.size;
        try {
            await bulkUpdateApplications({
                applicationIds: Array.from(this.selectedApplicationIds),
                action: this.bulkAction
            });
            await refreshApex(this.wiredBoard);
            this.selectedApplicationIds.clear();
            this.showToast(
                'Bulk action completed',
                `${count} applications ${this.bulkAction === 'reject' ? 'rejected' : 'advanced'}.`,
                'success'
            );
        } catch (error) {
            this.showToast('Bulk action failed', this.reduceError(error), 'error');
        } finally {
            this.isBusy = false;
        }
    }

    handleBulkCancel() {
        this.showBulkModal = false;
        this.bulkAction = null;
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
        let scoreClass = '';
        if (score !== null) {
            scoreClass = score >= 80 ? 'score-high' : score >= 60 ? 'score-medium' : 'score-low';
        }
        return {
            ...app,
            candidateName: app.candidateName || 'Unnamed candidate',
            positionName: app.positionName || 'No position',
            matchLabel: score === null ? 'No score' : `${score}%`,
            scoreClass,
            daysLabel: app.daysInStage ? `${app.daysInStage}d in stage` : 'New stage',
            priorityLabel: app.priority ? `${app.priority} priority` : 'Normal priority',
            cardClass: app.slaBreached ? 'application-card application-card_breached' : 'application-card',
            isSelected: this.selectedApplicationIds.has(app.id)
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

    matchesFilters(app) {
        // Department filter
        if (this.departmentFilter && app.department !== this.departmentFilter) {
            return false;
        }
        // Recruiter filter
        if (this.recruiterFilter && app.recruiter !== this.recruiterFilter) {
            return false;
        }
        // Position filter
        if (this.positionFilter && app.positionName !== this.positionFilter) {
            return false;
        }
        // Date range filter
        if (this.dateFromFilter && app.appliedDate < this.dateFromFilter) {
            return false;
        }
        if (this.dateToFilter && app.appliedDate > this.dateToFilter) {
            return false;
        }
        // SLA Status filter
        if (this.slaStatusFilter === 'Breached' && !app.slaBreached) {
            return false;
        }
        if (this.slaStatusFilter === 'At Risk' && (!app.slaAtRisk || app.slaBreached)) {
            return false;
        }
        // Top Matches filter
        if (this.showTopMatches && (app.matchScore === null || app.matchScore < 70)) {
            return false;
        }
        return true;
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
