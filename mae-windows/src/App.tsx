import { useState, useRef, useEffect } from "react";
import { MessageSquare, Settings, Trash2, ArrowUp, ImageIcon, X, Loader2 } from "lucide-react";
import { useAssistant } from "./hooks/useAssistant";
import "./App.css";

// TBD: Models and API integrations

export default function App() {
  const [showSettings, setShowSettings] = useState(false);
  const [inputText, setInputText] = useState("");
  const { messages, setMessages, processPrompt, isProcessing } = useAssistant();
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [messages]);

  const handleSend = async () => {
    const text = inputText;
    if (!text.trim() || isProcessing) return;
    setInputText("");
    await processPrompt(text);
  };

  return (
    <div className="app-container">
      <div className={`chat-view ${showSettings ? "hidden" : ""}`}>
        {/* Header */}
        <header className="header" data-tauri-drag-region>
          <div className="header-title">
            <MessageSquare size={18} />
            <span>Chat</span>
          </div>
          <div className="header-actions">
            <button onClick={() => setMessages([])} title="Limpar histórico">
              <Trash2 size={18} />
            </button>
            <button onClick={() => setShowSettings(true)} title="Configurações">
              <Settings size={18} />
            </button>
          </div>
        </header>

        {/* Chat List */}
        <div className="chat-list" ref={scrollRef}>
          {messages.length === 0 ? (
            <div className="empty-state">Sem Mensagens.</div>
          ) : (
            messages.map((m) => (
              <div key={m.id} className={`chat-bubble-container ${m.isUser ? "user" : "assistant"}`}>
                <div className={`chat-bubble ${m.isUser ? "user-bubble" : "assistant-bubble"}`}>
                  {m.text}
                </div>
              </div>
            ))
          )}
        </div>

        {/* Footer */}
        <footer className="footer">
          <button className="icon-btn" title="Anexar imagem (em breve)">
            <ImageIcon size={20} />
          </button>
          <div className="input-wrapper">
            <textarea
              placeholder="Envie uma mensagem..."
              value={inputText}
              onChange={(e) => setInputText(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter" && !e.shiftKey) {
                  e.preventDefault();
                  handleSend();
                }
              }}
              rows={1}
            />
          </div>
          <button
            className={`send-btn ${inputText.trim() && !isProcessing ? "active" : ""}`}
            onClick={handleSend}
            disabled={!inputText.trim() || isProcessing}
          >
            {isProcessing ? <Loader2 size={18} className="spin" /> : <ArrowUp size={18} />}
          </button>
        </footer>
      </div>

      {showSettings && (
        <div className="settings-view">
          <header className="header" data-tauri-drag-region>
            <div className="header-title">
              <Settings size={18} />
              <span>Configurações</span>
            </div>
            <button className="icon-btn" style={{ padding: 0 }} onClick={() => setShowSettings(false)}>
              <X size={20} />
            </button>
          </header>
          <div className="settings-content" style={{ padding: 20 }}>
            <h3 style={{ marginTop: 0 }}>Configurações (Em Breve)</h3>
            <p className="placeholder-text" style={{ color: 'var(--text-muted)', fontSize: 14 }}>
              Em breve: Modelos cloud vs Local (Ollama), System Prompts.
            </p>
          </div>
        </div>
      )}
    </div>
  );
}
