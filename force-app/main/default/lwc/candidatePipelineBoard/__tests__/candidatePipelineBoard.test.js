import { createElement } from '@lwc/engine-dom';
import CandidatePipelineBoard from 'c/candidatePipelineBoard';
import getPipelineBoard from '@salesforce/apex/RecruitmentLwcController.getPipelineBoard';
import updateApplicationStatus from '@salesforce/apex/RecruitmentLwcController.updateApplicationStatus';

jest.mock(
    '@salesforce/apex/RecruitmentLwcController.getPipelineBoard',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return {
            default: createApexTestWireAdapter(jest.fn())
        };
    },
    { virtual: true }
);

jest.mock(
    '@salesforce/apex/RecruitmentLwcController.updateApplicationStatus',
    () => ({
        default: jest.fn()
    }),
    { virtual: true }
);

jest.mock(
    'lightning/empApi',
    () => ({
        subscribe: jest.fn(() => Promise.resolve({ id: 'subscription' })),
        unsubscribe: jest.fn(),
        onError: jest.fn()
    }),
    { virtual: true }
);

const flushPromises = () => new Promise((resolve) => setTimeout(resolve, 0));

describe('c-candidate-pipeline-board', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('renders stages and application cards', async () => {
        const element = createElement('c-candidate-pipeline-board', {
            is: CandidatePipelineBoard
        });
        document.body.appendChild(element);

        getPipelineBoard.emit([
            {
                name: 'Screening',
                applications: [
                    {
                        id: 'a01xx0000000001',
                        candidateName: 'Ada Lovelace',
                        positionName: 'Apex Engineer',
                        matchScore: 92,
                        priority: 'High',
                        daysInStage: 2,
                        slaBreached: false
                    }
                ]
            }
        ]);
        await flushPromises();

        expect(element.shadowRoot.textContent).toContain('Ada Lovelace');
        expect(element.shadowRoot.textContent).toContain('92%');
    });

    it('updates status when a card is dropped into a stage', async () => {
        updateApplicationStatus.mockResolvedValue(undefined);
        const element = createElement('c-candidate-pipeline-board', {
            is: CandidatePipelineBoard
        });
        document.body.appendChild(element);

        getPipelineBoard.emit([
            {
                name: 'Screening',
                applications: [
                    {
                        id: 'a01xx0000000001',
                        candidateName: 'Ada Lovelace',
                        positionName: 'Apex Engineer'
                    }
                ]
            },
            { name: 'Interview 1', applications: [] }
        ]);
        await flushPromises();

        element.draggedApplicationId = 'a01xx0000000001';
        const targetStage = [...element.shadowRoot.querySelectorAll('.stage')].find(
            (stage) => stage.dataset.status === 'Interview 1'
        );
        const dropEvent = new CustomEvent('drop', { bubbles: true, composed: true });
        dropEvent.preventDefault = jest.fn();
        targetStage.dispatchEvent(dropEvent);
        await flushPromises();

        expect(updateApplicationStatus).toHaveBeenCalledWith({
            applicationId: 'a01xx0000000001',
            newStatus: 'Interview 1'
        });
    });
});
