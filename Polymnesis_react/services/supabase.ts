import { createClient } from '@supabase/supabase-js';
import { Card, SyncCredentials } from '../types';

let supabaseClient: any = null;

export const initSupabase = (creds: SyncCredentials) => {
  if (creds.enabled && creds.url && creds.key) {
    try {
      supabaseClient = createClient(creds.url, creds.key);
      return true;
    } catch (e) {
      console.error("Failed to init supabase", e);
      return false;
    }
  }
  supabaseClient = null;
  return false;
};

// Sync logic: Fetch all cards from DB
export const fetchRemoteCards = async (): Promise<Card[] | null> => {
  if (!supabaseClient) return null;
  
  const { data, error } = await supabaseClient
    .from('cards')
    .select('*');

  if (error) {
    console.error("Error fetching cards:", error);
    return null;
  }

  // Parse JSON data back to Card format
  return data.map((row: any) => ({
    ...row.data,
    id: row.id // Ensure ID matches
  }));
};

// Sync logic: Upsert a single card
export const upsertRemoteCard = async (card: Card) => {
  if (!supabaseClient) return;

  const { error } = await supabaseClient
    .from('cards')
    .upsert({ 
      id: card.id, 
      data: card,
      updated_at: new Date().toISOString()
    });

  if (error) console.error("Error saving card:", error);
};

// Sync logic: Delete a card
export const deleteRemoteCard = async (id: string) => {
  if (!supabaseClient) return;

  const { error } = await supabaseClient
    .from('cards')
    .delete()
    .eq('id', id);

  if (error) console.error("Error deleting card:", error);
};