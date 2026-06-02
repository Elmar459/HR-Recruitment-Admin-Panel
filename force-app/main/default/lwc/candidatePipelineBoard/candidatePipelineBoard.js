import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { subscribe, onError } from 'lightning/empApi';
import getPipelineBoard from '@salesforce/apex/RecruitmentLwcController.getPipelineBoard';
import updateApplicationStatus from '@salesforce/apex/RecruitmentLwcController.updateApplicationStatus';
import getFilterOptions from '@salesforce/apex/RecruitmentLwcController.getFilterOptions';
import bulkUpdateApplications from '@salesforce/apex/RecruitmentLwcController.bulkUpdateApplications';

const PIPELINE_CHANNEL = '/event/Application_Pipeline_Update__e';

export default class CandidatePipelineBoard extends NavigationMixin(LightningElement) {
    searchTerm = '';
    draggedApplicationId;
    stages = [];
    isBusy = false;
    errorMessage;
    subscription;
    isDraggingSelected = false; // флаг, что перетаскивается выделенная карточка

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
        onError(() => { });
        this.subscribeToPipelineUpdates();
        this.loadFilterOptions();
        this.refreshBoard();
    }

    async refreshBoard() {
        try {
            this.isBusy = true;
            const result = await getPipelineBoard();
            if (Array.isArray(result) && result.length > 0) {
                this.stages = result;
            } else {
                this.stages = this.getDefaultStages();
            }
            this.errorMessage = undefined;
        } catch (error) {
            this.errorMessage = 'Error loading pipeline: ' + this.reduceError(error);
            this.stages = this.getDefaultStages();
        } finally {
            this.isBusy = false;
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

    // Обработка клика по карточке с учётом Ctrl
    handleCardClick(event) {
        // Если клик был по имени или позиции, не меняем выделение
        if (event.target.classList.contains('clickable-name') || event.target.classList.contains('clickable-position')) {
            return;
        }

        const appId = event.currentTarget.dataset.id;
        const isCtrlPressed = event.ctrlKey || event.metaKey;

        if (isCtrlPressed) {
            if (this.selectedApplicationIds.has(appId)) {
                this.selectedApplicationIds.delete(appId);
            } else {
                this.selectedApplicationIds.add(appId);
            }
        } else {
            if (this.selectedApplicationIds.size === 1 && this.selectedApplicationIds.has(appId)) {
                this.selectedApplicationIds.clear();
            } else {
                this.selectedApplicationIds.clear();
                this.selectedApplicationIds.add(appId);
            }
        }
        this.selectedApplicationIds = new Set(this.selectedApplicationIds);
    }

    // Открытие записи кандидата
    handleCandidateNameClick(event) {
        event.stopPropagation();
        const candidateId = event.currentTarget.dataset.candidateId;
        if (candidateId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: candidateId,
                    objectApiName: 'Contact', // замените на свой API name
                    actionName: 'view'
                }
            });
        }
    }

    // Открытие записи позиции
    handlePositionNameClick(event) {
        event.stopPropagation();
        const positionId = event.currentTarget.dataset.positionId;
        if (positionId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: positionId,
                    objectApiName: 'Job_Opening__c', // замените на свой API name
                    actionName: 'view'
                }
            });
        }
    }

    // Drag & Drop с поддержкой множественного выделения
    handleDragStart(event) {
        const appId = event.currentTarget.dataset.id;
        this.draggedApplicationId = appId;
        this.isDraggingSelected = this.selectedApplicationIds.has(appId);
        event.dataTransfer.effectAllowed = 'move';
        event.currentTarget.classList.add('dragging');

        // Создаём "призрачную" копию для визуального отклика
        const rect = event.currentTarget.getBoundingClientRect();
        const ghost = event.currentTarget.cloneNode(true);
        ghost.style.position = 'absolute';
        ghost.style.top = '-1000px';
        ghost.style.left = '-1000px';
        ghost.style.width = `${rect.width}px`;
        ghost.style.opacity = '0.6';
        document.body.appendChild(ghost);
        event.dataTransfer.setDragImage(ghost, rect.width / 2, rect.height / 2);
        setTimeout(() => document.body.removeChild(ghost), 0);
    }

    handleDragEnd(event) {
        event.currentTarget.classList.remove('dragging');
        this.draggedApplicationId = undefined;
        this.isDraggingSelected = false;
    }

    handleDragOver(event) {
        event.preventDefault();
        event.dataTransfer.dropEffect = 'move';
    }

    handleDropOnCard(event) {
        event.preventDefault(); // Предотвращаем вложение карточки в карточку
    }

    async handleDrop(event) {
        event.preventDefault();
        const targetStatus = event.currentTarget.dataset.status;
        if (!this.draggedApplicationId || !targetStatus) {
            return;
        }

        let applicationIdsToMove = [];
        if (this.isDraggingSelected && this.selectedApplicationIds.size > 1) {
            // Перетаскиваем все выделенные карточки
            applicationIdsToMove = Array.from(this.selectedApplicationIds);
        } else {
            applicationIdsToMove = [this.draggedApplicationId];
        }

        this.isBusy = true;
        let successCount = 0;
        let errorCount = 0;

        try {
            // Последовательно обновляем каждую заявку
            for (const appId of applicationIdsToMove) {
                try {
                    await updateApplicationStatus({
                        applicationId: appId,
                        newStatus: targetStatus
                    });
                    successCount++;
                } catch (err) {
                    errorCount++;
                    console.error(`Failed to move ${appId}:`, err);
                }
            }
            await this.refreshBoard();
            // После переноса нескольких карточек снимаем выделение
            if (applicationIdsToMove.length > 1) {
                this.selectedApplicationIds.clear();
                this.selectedApplicationIds = new Set();
            }
            this.showToast(
                'Pipeline updated',
                `${successCount} application(s) moved to ${targetStatus}${errorCount > 0 ? `, ${errorCount} failed` : ''}.`,
                errorCount > 0 ? 'warning' : 'success'
            );
        } catch (error) {
            this.showToast('Could not update pipeline', this.reduceError(error), 'error');
        } finally {
            this.isBusy = false;
            this.draggedApplicationId = undefined;
            this.isDraggingSelected = false;
        }
    }

    handleRefresh() {
        this.refreshBoard();
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
            await this.refreshBoard();
            this.selectedApplicationIds.clear();
            this.selectedApplicationIds = new Set();
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
                await this.refreshBoard();
            });
        } catch (error) {
            this.subscription = undefined;
        }
    }

    decorateApplication(app) {
        const score = app.matchScore === null || app.matchScore === undefined ? null : Math.round(app.matchScore);
        let scoreClass = '';
        let matchLabel = 'No score';
        if (score !== null) {
            matchLabel = `${score}%`;
            scoreClass = score >= 80 ? 'slds-badge slds-theme_success' :
                score >= 60 ? 'slds-badge slds-theme_warning' :
                    'slds-badge slds-theme_error';
        } else {
            scoreClass = 'slds-badge';
        }

        const isSelected = this.selectedApplicationIds.has(app.id);
        const baseCardClass = 'slds-card slds-card_boundary slds-p-around_x-small card-draggable';
        const breachedClass = app.slaBreached ? 'card-breached' : '';
        const selectedClass = isSelected ? 'card-selected' : '';

        return {
            ...app,
            candidateName: app.candidateName || 'Unnamed candidate',
            positionName: app.positionName || 'No position',
            matchLabel,
            scoreClass,
            daysLabel: app.daysInStage ? `${app.daysInStage}d in stage` : 'New stage',
            priorityLabel: app.priority ? `${app.priority} priority` : 'Normal priority',
            cardClass: `${baseCardClass} ${breachedClass} ${selectedClass}`,
            isSelected
        };
    }

    matchesSearch(app, term) {
        if (!term) return true;
        return [app.candidateName, app.positionName, app.status, app.priority]
            .filter(Boolean)
            .some((value) => value.toLowerCase().includes(term));
    }

    matchesFilters(app) {
        if (this.departmentFilter && app.department !== this.departmentFilter) return false;
        if (this.recruiterFilter && app.recruiter !== this.recruiterFilter) return false;
        if (this.positionFilter && app.positionName !== this.positionFilter) return false;

        if (this.dateFromFilter && app.appliedDate && app.appliedDate < this.dateFromFilter) return false;
        if (this.dateToFilter && app.appliedDate && app.appliedDate > this.dateToFilter) return false;

        if (this.slaStatusFilter === 'Breached' && !app.slaBreached) return false;
        if (this.slaStatusFilter === 'At Risk' && (!app.slaAtRisk || app.slaBreached)) return false;

        if (this.showTopMatches && (app.matchScore === null || app.matchScore < 70)) return false;

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


    handleDragEnter(event) {
        event.currentTarget.classList.add('drag-over');
    }
    handleDragLeave(event) {
        event.currentTarget.classList.remove('drag-over');
    }
}