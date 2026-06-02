import { LightningElement, wire, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getCandidatesForPosition from '@salesforce/apex/CandidateComparisonController.getCandidatesForPosition';

const COLUMNS = [
    { 
        label: 'Name', 
        fieldName: 'nameUrl', 
        type: 'url', 
        typeAttributes: { 
            label: { fieldName: 'name' },
            target: '_blank'
        }
    },
    { label: 'Match Score', fieldName: 'matchScore', type: 'number', cellAttributes: { class: { fieldName: 'scoreClass' } } },
    { label: 'Experience (years)', fieldName: 'yearsOfExperience', type: 'number' },
    { label: 'Expected Salary', fieldName: 'expectedSalary', type: 'currency' },
    { label: 'Stage', fieldName: 'stage', type: 'text' },
    { label: 'SLA Breached', fieldName: 'slaBreached', type: 'boolean' }
];

export default class CandidateStatistics extends NavigationMixin(LightningElement) {
    @api recordId;
    @track candidates = [];
    @track error;
    columns = COLUMNS;

    get hasRecordId() {
        return !!this.recordId;
    }

    @wire(getCandidatesForPosition, { positionId: '$recordId' })
    wiredCandidates({ error, data }) {
        if (!this.hasRecordId) {
            this.candidates = [];
            return;
        }
        if (data) {
            this.candidates = data.map(candidate => ({
                id: candidate.id,
                name: candidate.name,
                nameUrl: this.getCandidateUrl(candidate.id),
                matchScore: candidate.matchScore,
                yearsOfExperience: candidate.yearsOfExperience,
                expectedSalary: candidate.expectedSalary,
                stage: candidate.stage,
                slaBreached: candidate.slaBreached,
                scoreClass: this.getScoreClass(candidate.matchScore)
            }));
            this.error = undefined;
        } else if (error) {
            this.error = error.body.message;
            this.showToast('Error', 'Failed to load candidates', 'error');
        }
    }

    getCandidateUrl(candidateId) {
        // Строит URL для навигации к записи кандидата
        return `/lightning/r/Candidate__c/${candidateId}/view`;
    }

    getScoreClass(score) {
        if (score >= 80) return 'slds-badge_success';
        if (score >= 60) return 'slds-badge_warning';
        return 'slds-badge_lightest';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}