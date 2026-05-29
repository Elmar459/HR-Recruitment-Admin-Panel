import { LightningElement, wire, track } from 'lwc';
import getTeamWorkload from '@salesforce/apex/RecruiterWorkloadController.getTeamWorkload';
import { refreshApex } from '@salesforce/apex';

const COLUMNS = [
    { label: 'Name', fieldName: 'userName', type: 'text', sortable: true },
    { label: 'Profile', fieldName: 'profileName', type: 'text', sortable: true },
    { label: 'Workload Score', fieldName: 'workloadScore', type: 'percent', sortable: true,
        cellAttributes: {
            iconName: { fieldName: 'scoreIcon' },
            iconLabel: { fieldName: 'scoreLabel' },
            iconPosition: 'right'
        }
    },
    { label: 'Active Apps', fieldName: 'activeApps', type: 'number', sortable: true },
    { label: 'Interviews (Week)', fieldName: 'interviewsThisWeek', type: 'number', sortable: true },
    { label: 'Offers Pending', fieldName: 'offersPending', type: 'number', sortable: true },
    { label: 'SLA Breaches', fieldName: 'slaBreaches', type: 'number', sortable: true,
        cellAttributes: {
            class: { fieldName: 'slaClass' }
        }
    }
];

export default class TeamWorkloadDashboard extends LightningElement {
    @track teamData = [];
    columns = COLUMNS;
    wiredResult;
    sortBy = 'workloadScore';
    sortDirection = 'asc';

    @wire(getTeamWorkload)
    wiredTeam(result) {
        this.wiredResult = result;
        if (result.data) {
            this.teamData = result.data.map(item => {
                let scoreIcon = '';
                let scoreLabel = '';
                if (item.workloadScore <= 40) {
                    scoreIcon = 'utility:success';
                    scoreLabel = 'Low';
                } else if (item.workloadScore <= 70) {
                    scoreIcon = 'utility:warning';
                    scoreLabel = 'Medium';
                } else {
                    scoreIcon = 'utility:error';
                    scoreLabel = 'High';
                }
                return {
                    ...item,
                    scoreIcon: scoreIcon,
                    scoreLabel: scoreLabel,
                    slaClass: item.slaBreaches > 0 ? 'slds-text-color_error' : ''
                };
            });
            this.sortData();
        } else if (result.error) {
            console.error('Error loading team workload', result.error);
        }
    }

    sortData() {
        const field = this.sortBy;
        const direction = this.sortDirection === 'asc' ? 1 : -1;
        this.teamData.sort((a, b) => {
            let valA = a[field];
            let valB = b[field];
            if (typeof valA === 'string') {
                return direction * valA.localeCompare(valB);
            }
            return direction * ((valA || 0) - (valB || 0));
        });
    }

    handleSort(event) {
        this.sortBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
        this.sortData();
    }

    refreshData() {
        refreshApex(this.wiredResult);
    }
}