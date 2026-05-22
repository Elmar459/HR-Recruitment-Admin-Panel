import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getInterviewTimeline from '@salesforce/apex/RecruitmentLwcController.getInterviewTimeline';
import updateApplicationStatus from '@salesforce/apex/RecruitmentLwcController.updateApplicationStatus';
import scheduleNextInterview from '@salesforce/apex/RecruitmentLwcController.scheduleNextInterview';

export default class InterviewTimeline extends NavigationMixin(LightningElement) {
    @api recordId;
    payload;
    wiredTimeline;
    errorMessage;
    expandedStageKey;
    isBusy = false;

    @wire(getInterviewTimeline, { applicationId: '$recordId' })
    loadTimeline(result) {
        this.wiredTimeline = result;
        const { data, error } = result;
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
        return `width: ${score}%`;
    }

    get slaLabel() {
        const remaining = Number(this.application?.slaDaysRemaining || 0);
        return remaining >= 0 ? `${remaining}d remaining` : `${Math.abs(remaining)}d overdue`;
    }

    get slaProgressStyle() {
        const days = Number(this.application?.daysInStage || 0);
        const percent = Math.max(0, Math.min(100, (days / 7) * 100));
        return `width: ${percent}%`;
    }

    get slaClass() {
        return this.application?.slaBreached || Number(this.application?.slaDaysRemaining || 0) < 0
            ? 'it-sla it-sla_overdue'
            : 'it-sla';
    }

    get stages() {
        return (this.payload?.stages || []).map((stage) => {
            const key = `${stage.numberValue}-${stage.type}`;
            const isCompleted = stage.state === 'completed';
            const isExpanded = this.expandedStageKey === key;
            const feedback = stage.interview?.feedbackDetails;
            return {
                ...stage,
                key,
                isCompleted,
                isActive: stage.state === 'active',
                canSchedule: stage.state === 'active' && !stage.interview,
                canOpenInterview: stage.state === 'active' && Boolean(stage.interview?.id),
                isExpanded,
                canExpand: isCompleted && Boolean(stage.interview),
                stepClass: `it-stage-card it-stage-card_${stage.state}${isExpanded ? ' it-stage-card_expanded' : ''}`,
                iconName: this.stageIcon(stage.state),
                variant: stage.state === 'rejected' ? 'error' : stage.state === 'completed' ? 'success' : 'inverse',
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
                comments: feedback?.comments || stage.interview?.feedback || 'No feedback comments yet.'
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
                style: `width: ${value}%`
            };
        });
    }

    get trendPoints() {
        const points = this.payload?.scoreTrend || [];
        if (points.length === 0) {
            return '';
        }
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

    async handleScheduleNext() {
        this.isBusy = true;
        try {
            await scheduleNextInterview({ applicationId: this.recordId });
            await refreshApex(this.wiredTimeline);
            this.showToast('Interview scheduled', 'Next interview was scheduled for the next business slot.', 'success');
        } catch (error) {
            this.showToast('Could not schedule interview', this.reduceError(error), 'error');
        } finally {
            this.isBusy = false;
        }
    }

    handleOpenStageInterview(event) {
        this.navigateToRecord(event.currentTarget.dataset.id);
    }

    handleStageClick(event) {
        const key = event.currentTarget.dataset.key;
        const canExpand = event.currentTarget.dataset.expandable === 'true';
        if (!canExpand) {
            return;
        }
        this.expandedStageKey = this.expandedStageKey === key ? undefined : key;
    }

    navigateToRecord(recordId) {
        if (!recordId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId,
                actionName: 'view'
            }
        });
    }

    stageIcon(state) {
        if (state === 'completed') {
            return 'utility:success';
        }
        if (state === 'rejected') {
            return 'utility:error';
        }
        if (state === 'active') {
            return 'utility:clock';
        }
        return 'utility:dash';
    }

    scoreLabel(value) {
        return value === null || value === undefined ? 'N/A' : `${Math.round(Number(value))}`;
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
