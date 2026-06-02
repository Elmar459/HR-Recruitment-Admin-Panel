import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCandidateSummary from '@salesforce/apex/CandidateSummaryService.getCandidateSummary';
import getNextInterview from '@salesforce/apex/CandidateSummaryService.getNextInterview';
import savePhoto from '@salesforce/apex/CandidatePhotoManager.savePhoto';
import createContentVersion from '@salesforce/apex/CandidatePhotoManager.createContentVersion';
import getContentDocumentId from '@salesforce/apex/CandidatePhotoManager.getContentDocumentId';
import getPhotoUrl from '@salesforce/apex/CandidatePhotoManager.getPhotoUrl';

export default class CandidatePhotoTile extends NavigationMixin(LightningElement) {
    @api recordId;
    @track candidateInfo = {};
    @track recentApplications = [];
    @track warnings = [];
    @track topSkills = [];
    @track selectedPositionId = null;
    @track selectedApplicationId = null;
    @track isLoadingPhoto = false;
    @track showMessagingModal = false;
    @track showInterviewFlow = false;
    @track flowInputs = [];
    @track nextInterview = null;

    resourceVersionLinkedIn = '1779903973000';
    resourceVersionPhone = '1779903994000';

    wiredSummaryResult;

    // Уникальные позиции для кнопок
    get uniquePositions() {
        const map = new Map();
        this.recentApplications.forEach(app => {
            if (app.positionId && app.positionName && !map.has(app.positionId)) {
                map.set(app.positionId, {
                    id: app.positionId,
                    name: app.positionName,
                    buttonClass: this.getPositionButtonClass(app.positionId)
                });
            }
        });
        return Array.from(map.values());
    }

    // Фильтр заявок по выбранной позиции
    get filteredApplications() {
        if (!this.selectedPositionId) return [];
        return this.recentApplications
            .filter(app => app.positionId === this.selectedPositionId)
            .map(app => ({
                ...app,
                linkClass: this.getApplicationLinkClass(app.id)
            }));
    }

    get showNoApplicationsMessage() {
        return this.filteredApplications.length === 0 && this.selectedPositionId;
    }

    // Выбранная заявка (объект)
    get selectedApplication() {
        return this.recentApplications.find(app => app.id === this.selectedApplicationId) || null;
    }

    get selectedStage() {
        const app = this.selectedApplication;
        if (!app) return '';
        if (app.status === 'Rejected') {
            return 'Rejected';  // или можно вернуть app.status
        }
        return app.stage || app.status;
    }
    get selectedAppliedDate() {
        const date = this.selectedApplication?.appliedDate;
        if (!date) return '';
        const d = new Date(date);
        return `${d.getMonth() + 1}/${d.getDate()}/${d.getFullYear()}`;
    }
    get selectedDaysInStage() {
        return this.selectedApplication?.daysInStage ?? '';
    }
    get selectedMatchScore() {
        return this.selectedApplication?.matchScore ?? 0;
    }
    get selectedSla() {
        return this.selectedApplication?.sla || null;
    }
    get selectedStageOrder() {
        return this.selectedApplication?.currentStageOrder || 0;
    }
    get selectedTotalStages() {
        return this.selectedApplication?.totalStages || 1;
    }
    get stageProgressPercent() {
        if (this.selectedTotalStages === 0) return 0;
        return Math.round((this.selectedStageOrder / this.selectedTotalStages) * 100);
    }
    get stageProgressStyle() {
        return `width: ${this.stageProgressPercent}%; background-color: #2e844a;`;
    }
    get formattedNextInterviewDate() {
        if (!this.nextInterview?.scheduledTime) return '';
        const d = new Date(this.nextInterview.scheduledTime);
        return `${d.toLocaleDateString()} ${d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`;
    }
    get progressBarStyle() {
        const score = this.selectedMatchScore;
        let color = '#ba0517';
        if (score >= 70) color = '#2e844a';
        else if (score >= 50) color = '#e6a700';
        return `width: ${score}%; background-color: ${color};`;
    }
    get slaIcon() {
        const sla = this.selectedSla;
        if (!sla) return 'utility:event';
        if (sla.status === 'good') return 'utility:success';
        if (sla.status === 'warning') return 'utility:warning';
        return 'utility:error';
    }
    get slaIconClass() {
        const sla = this.selectedSla;
        if (!sla) return '';
        if (sla.status === 'good') return 'sla-good';
        if (sla.status === 'warning') return 'sla-warning';
        return 'sla-breached';
    }
    get slaText() {
        const sla = this.selectedSla;
        if (!sla) return 'No SLA configured';
        if (sla.status === 'good') return `${sla.remainingDays} days left`;
        if (sla.status === 'warning') return `${sla.remainingDays} days left (soon)`;
        return `Overdue by ${sla.overdueDays} days`;
    }
    get slaTextClass() {
        const sla = this.selectedSla;
        if (!sla) return '';
        if (sla.status === 'good') return 'sla-good-text';
        if (sla.status === 'warning') return 'sla-warning-text';
        return 'sla-breached-text';
    }
    get linkedinIconUrl() {
        return `${window.location.origin}/resource/${this.resourceVersionLinkedIn}/LinkedInIcon`;
    }
    get phoneIconUrl() {
        return `${window.location.origin}/resource/${this.resourceVersionPhone}/PhoneIcon`;
    }

    @wire(getCandidateSummary, { candidateId: '$recordId' })
    wiredSummary(result) {
        this.wiredSummaryResult = result;
        if (result.data) {
            this.candidateInfo = result.data.candidate || {};
            this.recentApplications = result.data.recentApplications || [];
            this.warnings = result.data.warnings || [];
            this.topSkills = result.data.topSkills || [];
            this.initSelection();
        } else if (result.error) {
            console.error('Apex error', result.error);
        }
    }

    initSelection() {
        if (this.recentApplications.length === 0) return;
        // Уникальные позиции
        const unique = this.uniquePositions;
        if (unique.length === 0) return;
        // Выбираем первую позицию, если ещё не выбрана
        if (!this.selectedPositionId) {
            this.selectedPositionId = unique[0].id;
        }
        // Выбираем первую заявку из отфильтрованных
        const filtered = this.filteredApplications;
        if (filtered.length > 0 && !this.selectedApplicationId) {
            this.selectedApplicationId = filtered[0].id;
            this.loadNextInterview();
        } else if (this.selectedApplicationId) {
            // Если заявка уже выбрана, но может не принадлежать текущей позиции – исправляем
            const stillValid = filtered.some(app => app.id === this.selectedApplicationId);
            if (!stillValid && filtered.length > 0) {
                this.selectedApplicationId = filtered[0].id;
                this.loadNextInterview();
            }
        }
    }

    async loadNextInterview() {
        if (!this.selectedApplicationId) return;
        try {
            const next = await getNextInterview({ applicationId: this.selectedApplicationId });
            this.nextInterview = next;
        } catch (error) {
            console.error('Error loading next interview', error);
        }
    }

    selectPosition(event) {
        const positionId = event.currentTarget.dataset.positionId;
        if (this.selectedPositionId === positionId) return;
        this.selectedPositionId = positionId;
        const filtered = this.filteredApplications;
        if (filtered.length > 0) {
            this.selectedApplicationId = filtered[0].id;
            this.loadNextInterview();
        } else {
            this.selectedApplicationId = null;
            this.nextInterview = null;
        }
        if (this.wiredSummaryResult) refreshApex(this.wiredSummaryResult);
    }

    navigateToApplication(event) {
        const appId = event.currentTarget.dataset.id;
        if (!appId) return;
        event.preventDefault();
        this.selectedApplicationId = appId;
        this.loadNextInterview();
        if (this.wiredSummaryResult) refreshApex(this.wiredSummaryResult);
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: appId,
                objectApiName: 'Application__c',
                actionName: 'view'
            }
        });
    }

    navigateToSkill(event) {
        const skillId = event.currentTarget.dataset.id;
        if (!skillId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: skillId,
                objectApiName: 'Candidate_Skill__c',
                actionName: 'view'
            }
        });
    }

    getPositionButtonClass(positionId) {
        return positionId === this.selectedPositionId ? 'position-chip active' : 'position-chip';
    }

    getApplicationLinkClass(appId) {
        return appId === this.selectedApplicationId ? 'application-link selected' : 'application-link';
    }

    handleUploadClick() {
        const input = document.createElement('input');
        input.type = 'file';
        input.accept = 'image/jpeg, image/png, image/jpg';
        input.style.display = 'none';
        input.addEventListener('change', this.handleFileChange.bind(this));
        document.body.appendChild(input);
        input.click();
    }

    async handleFileChange(event) {
        const file = event.target.files[0];
        if (!file) return;
        if (!file.type.match('image/jpeg') && !file.type.match('image/png')) {
            this.showToast('Error', 'Only JPEG and PNG images are allowed.', 'error');
            return;
        }
        this.isLoadingPhoto = true;
        const reader = new FileReader();
        reader.onload = async () => {
            const base64 = reader.result.split(',')[1];
            try {
                const cvId = await createContentVersion({ fileName: file.name, base64Data: base64, mimeType: file.type });
                const docId = await getContentDocumentId({ contentVersionId: cvId });
                await savePhoto({ candidateId: this.recordId, contentDocumentId: docId });
                this.showToast('Success', 'Photo updated.', 'success');
                const newPhotoUrl = await getPhotoUrl({ candidateId: this.recordId });
                this.candidateInfo.photoUrl = newPhotoUrl;
            } catch (error) {
                this.showToast('Error', error.body?.message || 'Upload failed', 'error');
            } finally {
                this.isLoadingPhoto = false;
                event.target.value = '';
                event.target.remove();
            }
        };
        reader.readAsDataURL(file);
    }

    openInterviewFlow() {
        if (!this.selectedApplicationId) {
            this.showToast('No active application', 'Select an application to schedule interview.', 'warning');
            return;
        }
        this.flowInputs = [{ name: 'recordId', type: 'String', value: this.selectedApplicationId }];
        this.showInterviewFlow = true;
    }
    closeInterviewFlow() {
        this.showInterviewFlow = false;
    }
    openMessagingModal() {
        if (!this.selectedApplicationId) {
            this.showToast('No active application', 'Select an application to send messages.', 'warning');
            return;
        }
        this.showMessagingModal = true;
    }
    closeMessagingModal() {
        this.showMessagingModal = false;
    }
    handleFlowStatusChange(event) {
        if (event.detail.status === 'FINISHED') {
            this.closeInterviewFlow();
            this.showToast('Interview Scheduled', 'The interview has been scheduled successfully.', 'success');
            refreshApex(this.wiredSummaryResult);
            this.loadNextInterview();
        }
    }
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
    stopPropagation(event) {
        event.stopPropagation();
    }
}