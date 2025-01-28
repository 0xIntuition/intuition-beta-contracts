window.addEventListener('load', (event) => {
    mermaid.initialize({
        startOnLoad: true,
        theme: 'dark',
        securityLevel: 'loose',
        themeVariables: {
            darkMode: true,
            xyChart: {
                backgroundColor: '#1f2937',
                titleColor: '#ffffff',
                gridColor: '#374151',
                xAxisLabelColor: '#9ca3af',
                yAxisLabelColor: '#9ca3af',
                plotColorPalette: '#6366f1'
            }
        },
        mindmap: {
            padding: 10,
            useMaxWidth: true
        }
    });
});
