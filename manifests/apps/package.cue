package apps

#WorkflowTemplate: {
	apiVersion: "argoproj.io/v1alpha1"
	kind:       "WorkflowTemplate"
	metadata: {
		name:      string
		namespace: string
	}
	spec: {
		entrypoint: string
		arguments?: {
			parameters?: [...{
				name:  string
				value: string
			}]
		}
		templates: [..._]
	}
}

printVariableWorkflowTemplate: #WorkflowTemplate & {
	metadata: {
		name:      "print-variable"
		namespace: "argo"
	}
	spec: {
		entrypoint: "pipeline"
		arguments: {
			parameters: [{
				name:  "message"
				value: "hello"
			}]
		}
		templates: [
			{
				name: "pipeline"
				steps: [
					[{
						name:     "print"
						template: "print-step"
					}],
				]
			},
			{
				name: "print-step"
				container: {
					image:   "alpine:latest"
					command: ["echo"]
					args:    ["Message: {{workflow.parameters.message}}"]
				}
			},
		]
	}
}
