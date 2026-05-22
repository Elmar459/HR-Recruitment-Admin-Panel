import { createElement } from '@lwc/engine-dom';
import InterviewTimeline from 'c/interviewTimeline';
import getInterviewTimeline from '@salesforce/apex/RecruitmentLwcController.getInterviewTimeline';

jest.mock(
    '@salesforce/apex/RecruitmentLwcController.getInterviewTimeline',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return {
            default: createApexTestWireAdapter(jest.fn())
        };
    },
    { virtual: true }
);

const flushPromises = () => new Promise((resolve) => setTimeout(resolve, 0));

describe('c-interview-timeline', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    it('renders application summary and interviews', async () => {
        const element = createElement('c-interview-timeline', {
            is: InterviewTimeline
        });
        element.recordId = 'a01xx0000000001';
        document.body.appendChild(element);

        getInterviewTimeline.emit({
            application: {
                candidateName: 'Grace Hopper',
                positionName: 'Platform Architect',
                status: 'Interview 1',
                matchScore: 88
            },
            matchDetails: [{ label: 'Overall Match', value: 88 }],
            interviews: [
                {
                    id: 'a02xx0000000001',
                    type: 'Technical',
                    status: 'Completed',
                    interviewerName: 'Alan Turing',
                    score: 90,
                    dateTimeValue: '2026-05-22T10:00:00.000Z'
                }
            ]
        });
        await flushPromises();

        expect(element.shadowRoot.textContent).toContain('Grace Hopper');
        expect(element.shadowRoot.textContent).toContain('Technical');
        expect(element.shadowRoot.textContent).toContain('88%');
    });
});
