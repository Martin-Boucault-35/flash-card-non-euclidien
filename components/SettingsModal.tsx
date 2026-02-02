import React, { useState } from 'react';
import { X, Cloud, Save, AlertTriangle } from 'lucide-react';
import { Button } from './Button';
import { SyncCredentials } from '../types';

interface SettingsModalProps {
  isOpen: boolean;
  onClose: () => void;
  credentials: SyncCredentials;
  onSave: (creds: SyncCredentials) => void;
}

export const SettingsModal: React.FC<SettingsModalProps> = ({ 
  isOpen, 
  onClose, 
  credentials, 
  onSave 
}) => {
  const [formData, setFormData] = useState(credentials);
  const [showHelp, setShowHelp] = useState(false);

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm animate-fade-in">
      <div className="bg-slate-900 border border-slate-700 w-full max-w-lg rounded-2xl shadow-2xl flex flex-col max-h-[90vh]">
        
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-slate-800">
          <h2 className="text-xl font-bold text-white flex items-center gap-2">
            <Cloud className="text-indigo-400" /> Synchronisation Cloud
          </h2>
          <button onClick={onClose} className="text-slate-400 hover:text-white transition-colors">
            <X className="w-6 h-6" />
          </button>
        </div>

        {/* Body */}
        <div className="p-6 overflow-y-auto space-y-6">
          <div className="bg-slate-800/50 p-4 rounded-xl border border-slate-700">
            <p className="text-sm text-slate-300 mb-2">
              Pour synchroniser vos cartes entre PC et Mobile, vous devez créer un projet gratuit sur <strong>Supabase.com</strong>.
            </p>
            <button 
              onClick={() => setShowHelp(!showHelp)}
              className="text-xs text-indigo-400 hover:text-indigo-300 font-medium underline"
            >
              {showHelp ? "Masquer les instructions" : "Comment faire ? (Instructions SQL)"}
            </button>

            {showHelp && (
              <div className="mt-4 p-3 bg-black/30 rounded-lg text-xs font-mono text-slate-400 overflow-x-auto">
                <p className="mb-2 text-slate-500">// 1. Créez un projet sur Supabase</p>
                <p className="mb-2 text-slate-500">// 2. Allez dans SQL Editor et exécutez ceci :</p>
                <code className="text-emerald-400 block mb-4">
                  create table cards (<br/>
                  &nbsp;&nbsp;id text primary key,<br/>
                  &nbsp;&nbsp;data jsonb,<br/>
                  &nbsp;&nbsp;updated_at timestamptz default now()<br/>
                  );<br/>
                  <br/>
                  alter table cards enable row level security;<br/>
                  create policy "Public Access" on cards for all using (true);
                </code>
                <p className="text-slate-500">// 3. Copiez l'URL et la Clé Anon depuis Project Settings > API</p>
              </div>
            )}
          </div>

          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-slate-300 mb-1">Project URL</label>
              <input 
                type="text" 
                placeholder="https://xyz.supabase.co"
                value={formData.url}
                onChange={e => setFormData({...formData, url: e.target.value})}
                className="w-full bg-slate-950 border border-slate-800 rounded-lg px-4 py-2 text-white focus:ring-2 focus:ring-indigo-500 outline-none font-mono text-sm"
              />
            </div>
            
            <div>
              <label className="block text-sm font-medium text-slate-300 mb-1">API Key (public/anon)</label>
              <input 
                type="password" 
                placeholder="eyJhbGciOiJIUzI1NiIsInR5..."
                value={formData.key}
                onChange={e => setFormData({...formData, key: e.target.value})}
                className="w-full bg-slate-950 border border-slate-800 rounded-lg px-4 py-2 text-white focus:ring-2 focus:ring-indigo-500 outline-none font-mono text-sm"
              />
            </div>

            <div className="flex items-center gap-2 mt-4">
              <input 
                type="checkbox"
                id="enableSync"
                checked={formData.enabled}
                onChange={e => setFormData({...formData, enabled: e.target.checked})}
                className="w-4 h-4 rounded border-slate-700 bg-slate-900 text-indigo-600 focus:ring-indigo-500"
              />
              <label htmlFor="enableSync" className="text-sm text-slate-200 cursor-pointer">
                Activer la synchronisation
              </label>
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="p-6 border-t border-slate-800 flex justify-end gap-3">
            <Button variant="ghost" onClick={onClose}>Annuler</Button>
            <Button onClick={() => onSave(formData)}>
                <Save className="w-4 h-4" /> Enregistrer & Sync
            </Button>
        </div>
      </div>
    </div>
  );
};