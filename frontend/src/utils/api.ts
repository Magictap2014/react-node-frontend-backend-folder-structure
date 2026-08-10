const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000';

const getJsonHeaders = () => ({
  'Content-Type': 'application/json',
  'x-timezone': Intl.DateTimeFormat().resolvedOptions().timeZone,
});

export const api = {
  async get(endpoint: string) {
    const response = await fetch(`${API_BASE_URL}${endpoint}`, {
      method: 'GET',
      headers: getJsonHeaders(),
    });
    if (!response.ok) throw new Error('API request failed');
    return response.json();
  },

  async post(endpoint: string, data: unknown) {
    const response = await fetch(`${API_BASE_URL}${endpoint}`, {
      method: 'POST',
      headers: getJsonHeaders(),
      body: JSON.stringify(data),
    });
    if (!response.ok) throw new Error('API request failed');
    return response.json();
  },

  async delete(endpoint: string) {
    const response = await fetch(`${API_BASE_URL}${endpoint}`, {
      method: 'DELETE',
      headers: getJsonHeaders(),
    });
    if (!response.ok) throw new Error('API request failed');
    return response.json();
  },
};
