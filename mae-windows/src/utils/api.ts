export type InferenceMode = 'local' | 'api';
export type CloudProvider = 'google' | 'openai' | 'anthropic' | 'custom';

// Mocks the SettingsManager behavior from the Swift code
export const SettingsManager = {
    get inferenceMode(): InferenceMode { return 'local'; },
    get localModelName(): string { return 'gemma3:4b'; },
    get systemPrompt(): string { return 'Responda APENAS com a letra e o texto da alternativa. Sem introduções. Pergunta: '; },
    get selectedProvider(): CloudProvider { return 'google'; },
    get apiEndpoint(): string { return 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions'; },
    get apiModelName(): string { return 'gemini-2.5-flash'; },
    get apiKey(): string { return ''; } // Would be fetched from tauri-plugin-store
};

export async function fetchLocalOllama(prompt: string, model: string, system: string, images?: string[]) {
    const fullPrompt = system + prompt;
    const payload: any = {
        model,
        prompt: fullPrompt,
        stream: false,
        options: {
            temperature: 0.0
        }
    };
    
    if (images && images.length > 0) {
        payload.images = images;
    }

    const response = await fetch('http://localhost:11434/api/generate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
    });

    if (!response.ok) {
        throw new Error(`Local Ollama Erro: ${response.status}`);
    }

    const data = await response.json();
    return data.response.trim();
}

export async function executeAIRequest(prompt: string, images?: string[]): Promise<string> {
    const mode = SettingsManager.inferenceMode;
    const system = SettingsManager.systemPrompt;

    if (mode === 'local') {
        return fetchLocalOllama(prompt, SettingsManager.localModelName, system, images);
    } else {
        // Cloud API logic structure
        return Promise.resolve("Cloud APIs to be connected via tauri-plugin-http.");
    }
}
