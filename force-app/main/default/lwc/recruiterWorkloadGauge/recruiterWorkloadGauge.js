import { LightningElement, wire, track } from 'lwc';
import getCurrentRecruiterWorkload from '@salesforce/apex/RecruiterWorkloadController.getCurrentRecruiterWorkload';
import { refreshApex } from '@salesforce/apex';

export default class RecruiterWorkloadGauge extends LightningElement {
    @track workloadScore = 0;
    @track slaBreaches = 0;
    @track lastUpdated = null;
    
    wiredResult;
    activeArcPath = '';
    arcColor = '#2e844a';

    get hasSlaBreaches() {
        return this.slaBreaches > 0;
    }

    @wire(getCurrentRecruiterWorkload)
    wiredWorkload(result) {
        this.wiredResult = result;
        if (result.data) {
            this.workloadScore = result.data.workloadScore;
            this.slaBreaches = result.data.slaBreaches;
            this.lastUpdated = result.data.lastUpdated;
            this.updateArcAndColor();
        } else if (result.error) {
            console.error('Error loading workload', result.error);
            this.workloadScore = 0;
        }
    }

    updateArcAndColor() {
        const percent = Math.min(100, Math.max(0, this.workloadScore)) / 100;
        const radius = 30;
        const startAngle = -90;
        const endAngle = startAngle + (360 * percent);
        
        const start = this.polarToCartesian(50, 50, radius, startAngle);
        const end = this.polarToCartesian(50, 50, radius, endAngle);
        const largeArcFlag = percent > 0.5 ? 1 : 0;
        
        this.activeArcPath = `M ${start.x} ${start.y} A ${radius} ${radius} 0 ${largeArcFlag} 1 ${end.x} ${end.y}`;
        
        if (this.workloadScore <= 40) this.arcColor = '#2e844a';
        else if (this.workloadScore <= 70) this.arcColor = '#ffb75d';
        else this.arcColor = '#c23934';
    }

    polarToCartesian(centerX, centerY, radius, angleDeg) {
        const angleRad = (angleDeg - 90) * Math.PI / 180.0;
        return {
            x: centerX + radius * Math.cos(angleRad),
            y: centerY + radius * Math.sin(angleRad)
        };
    }

    refreshData() {
        refreshApex(this.wiredResult);
    }
}