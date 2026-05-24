import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getInterviewTimeline from '@salesforce/apex/RecruitmentLwcController.getInterviewTimeline';
import updateApplicationStatus from '@salesforce/apex/RecruitmentLwcController.updateApplicationStatus';
import getNearestAvailableSlot from '@salesforce/apex/RecruitmentLwcController.getNearestAvailableSlot';
import scheduleInterviewAtSlot from '@salesforce/apex/RecruitmentLwcController.scheduleInterviewAtSlot';

export default class InterviewTimeline extends NavigationMixin(LightningElement) {
    @api recordId;
    wiredTimeline;
    errorMessage;
    expandedStageKey;
    isBusy = false;
    isLoading = true;
    showScheduleModal = false;
    selectedDateTime = null;
    suggestedSlotRaw = null;
    isScheduling = false;
    activeStageKey = null;
    payload = null;

    @wire(getInterviewTimeline, { applicationId: '$recordId' })
    loadTimeline(result) {
        this.wiredTimeline = result;
        const { data, error } = result;
        this.isLoading = false;
        if (data) {
            this.payload = data;
            this.errorMessage = undefined;
        } else if (error) {
            this.payload = undefined;
            this.errorMessage = this.reduceError(error);
        }
    }

    get application() {
        return this.payload?.application;
    }

    get hasApplication() {
        return Boolean(this.application);
    }

    get statusOptions() {
        return this.payload?.statusOptions || [];
    }

    get matchLabel() {
        const score = this.application?.matchScore;
        return score === null || score === undefined ? 'No score' : `${Math.round(score)}%`;
    }

    get matchProgressStyle() {
        const score = Math.max(0, Math.min(100, Number(this.application?.matchScore || 0)));
        return `width: ${score}%;`;
    }

    get slaLabel() {
        const remaining = Number(this.application?.slaDaysRemaining || 0);
        return remaining >= 0 ? `${remaining}d remaining` : `${Math.abs(remaining)}d overdue`;
    }

    get slaProgressStyle() {
        const days = Number(this.application?.daysInStage || 0);
        const percent = Math.max(0, Math.min(100, (days / 7) * 100));
        return `width: ${percent}%;`;
    }

    get slaClass() {
        return this.application?.slaBreached || Number(this.application?.slaDaysRemaining || 0) < 0
            ? 'it-sla it-sla_overdue'
            : 'it-sla';
    }

    get stages() {
        return (this.payload?.stages || []).map((stage) => {
            const key = `${stage.numberValue}-${stage.type}`;
            const stateValue = stage.state || 'pending';
            const isCompleted = stateValue === 'completed';
            const isExpanded = this.expandedStageKey === key;
            const feedback = stage.interview?.feedbackDetails;
            return {
                ...stage,
                key,
                state: stateValue,
                isCompleted,
                isActive: stateValue === 'active',
                canSchedule: stateValue === 'active' && !stage.interview,
                canOpenInterview: stateValue === 'active' && Boolean(stage.interview?.id),
                isExpanded,
                canExpand: isCompleted && Boolean(stage.interview),
                stepClass: `it-stage-card it-stage-card_${stateValue}`,
                iconName: this.stageIcon(stateValue),
                variant: stateValue === 'rejected' ? 'error' : stateValue === 'completed' ? 'success' : 'inverse',
                dateLabel: stage.dateTimeValue ? new Intl.DateTimeFormat(undefined, {
                    dateStyle: 'medium',
                    timeStyle: 'short'
                }).format(new Date(stage.dateTimeValue)) : 'Not scheduled',
                interviewerName: stage.interview?.interviewerName || 'Interviewer not assigned',
                recommendation: feedback?.recommendation || stage.interview?.recommendation || 'No recommendation',
                technicalScore: this.scoreLabel(feedback?.technicalScore),
                communicationScore: this.scoreLabel(feedback?.communicationScore),
                cultureFitScore: this.scoreLabel(feedback?.cultureFitScore),
                compositeScore: this.scoreLabel(feedback?.compositeScore || stage.score),
                strengths: feedback?.strengths || 'No strengths captured yet.',
                weaknesses: feedback?.weaknesses || 'No weaknesses captured yet.',
                comments: feedback?.comments || stage.interview?.feedback || 'No feedback comments yet.',
                interviewUrl: stage.interview?.id ? `/lightning/r/Interview__c/${stage.interview.id}/view` : null
            };
        });
    }

    get matchDetails() {
        return (this.payload?.matchDetails || []).map((item) => {
            const value = Math.max(0, Math.min(100, Number(item.value || 0)));
            const weighted = item.weightedValue === null || item.weightedValue === undefined
                ? null
                : Math.round(item.weightedValue);
            return {
                ...item,
                valueLabel: `${Math.round(value)}%`,
                weightedLabel: weighted === null ? '' : `${weighted} weighted`,
                style: `width: ${value}%;`
            };
        });
    }

    get trendPoints() {
        const points = this.payload?.scoreTrend || [];
        if (points.length === 0) return '';
        if (points.length === 1) {
            const y = 100 - Number(points[0].score || 0);
            return `8,${y} 192,${y}`;
        }
        return points.map((point, index) => {
            const x = 8 + (index * 184) / (points.length - 1);
            const y = 100 - Math.max(0, Math.min(100, Number(point.score || 0)));
            return `${x},${y}`;
        }).join(' ');
    }

    get trendLabels() {
        return (this.payload?.scoreTrend || []).map((point) => ({
            key: point.label,
            label: point.label,
            score: this.scoreLabel(point.score)
        }));
    }

    get hasTrend() {
        return Boolean(this.trendPoints);
    }

    get suggestedSlotFormatted() {
        if (!this.suggestedSlotRaw) return '—';
        return new Intl.DateTimeFormat(undefined, {
            dateStyle: 'full',
            timeStyle: 'short'
        }).format(new Date(this.suggestedSlotRaw));
    }

    handleOpenCandidate() {
        this.navigateToRecord(this.application?.candidateId);
    }

    handleOpenPosition() {
        this.navigateToRecord(this.application?.positionId);
    }

    async handleStatusChange(event) {
        this.isBusy = true;
        try {
            await updateApplicationStatus({
                applicationId: this.recordId,
                newStatus: event.detail.value
            });
            await refreshApex(this.wiredTimeline);
            this.showToast('Status updated', 'Application status was updated.', 'success');
        } catch (error) {
            this.showToast('Could not update status', this.reduceError(error), 'error');
        } finally {
            this.isBusy = false;
        }
    }

    async handleScheduleNext(event) {
        const stageKey = event.currentTarget.dataset.stageKey;
        if (!stageKey) return;
        this.activeStageKey = stageKey;
        this.isBusy = true;
        try {
            const nearestSlot = await getNearestAvailableSlot({ applicationId: this.recordId });
            this.suggestedSlotRaw = nearestSlot;
            const dateObj = new Date(nearestSlot);
            if (isNaN(dateObj.getTime())) {
                throw new Error('Invalid date received from server');
            }
            const year = dateObj.getFullYear();
            const month = String(dateObj.getMonth() + 1).padStart(2, '0');
            const day = String(dateObj.getDate()).padStart(2, '0');
            const hours = String(dateObj.getHours()).padStart(2, '0');
            const minutes = String(dateObj.getMinutes()).padStart(2, '0');
            this.selectedDateTime = `${year}-${month}-${day}T${hours}:${minutes}`;
            this.showScheduleModal = true;
        } catch (error) {
            console.error('Error fetching nearest slot:', error);
            this.showToast('Cannot fetch available slot', this.reduceError(error), 'error');
        } finally {
            this.isBusy = false;
        }
    }

    handleCloseModal() {
        this.showScheduleModal = false;
        this.selectedDateTime = null;
        this.suggestedSlotRaw = null;
        this.activeStageKey = null;
    }

    handleDateTimeChange(event) {
        this.selectedDateTime = event.detail.value;
    }

    async handleConfirmSchedule() {
        if (!this.selectedDateTime) {
            this.showToast('Missing time', 'Please select date and time for the interview.', 'warning');
            return;
        }
        let isoDateTime;
        try {
            const localDate = new Date(this.selectedDateTime);
            if (isNaN(localDate.getTime())) {
                throw new Error('Invalid date/time');
            }
            isoDateTime = localDate.toISOString();
        } catch (e) {
            this.showToast('Invalid date/time', 'Selected date and time could not be parsed.', 'error');
            return;
        }
        this.isScheduling = true;
        try {
            await scheduleInterviewAtSlot({
                applicationId: this.recordId,
                selectedTime: isoDateTime
            });
            await refreshApex(this.wiredTimeline);
            this.showToast('Interview scheduled', `Interview scheduled at ${this.selectedDateTime.replace('T', ' ')}`, 'success');
            this.handleCloseModal();
        } catch (error) {
            console.error('Error scheduling interview:', error);
            this.showToast('Scheduling failed', this.reduceError(error), 'error');
        } finally {
            this.isScheduling = false;
        }
    }

    handleStageClick(event) {
        const key = event.currentTarget.dataset.key;
        const canExpand = event.currentTarget.dataset.expandable === 'true';
        if (!canExpand) return;
        this.expandedStageKey = this.expandedStageKey === key ? undefined : key;
    }

    navigateToRecord(recordId) {
        if (!recordId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId, actionName: 'view' }
        });
    }

    stageIcon(state) {
        if (state === 'completed') return 'utility:success';
        if (state === 'rejected') return 'utility:error';
        if (state === 'active') return 'utility:clock';
        if (state === 'pending') return 'utility:clock';
        return 'utility:dash';
    }

    scoreLabel(value) {
        return value === null || value === undefined ? 'N/A' : `${Math.round(Number(value))}`;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) return error.body.map(item => item.message).join(', ');
        if (error?.body?.message) return error.body.message;
        if (error?.message) return error.message;
        return 'Unexpected error';
    }
}