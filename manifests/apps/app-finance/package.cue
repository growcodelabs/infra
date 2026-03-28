package appfinance

import apps "growcodelabs.com:apps"

workflow: {
	apiVersion: "argoproj.io/v1alpha1"
	kind:       "Workflow"
	metadata: {
		name:      "print-variable-run"
		namespace: "argo"
	}
	spec: {
		workflowTemplateRef: {
			name: apps.printVariableWorkflowTemplate.metadata.name
		}
		arguments: {
			parameters: [{
				name:  "message"
				value: "Hello from Cue!"
			}]
		}
	}
}

objects: [
	apps.printVariableWorkflowTemplate,
	workflow,
]
