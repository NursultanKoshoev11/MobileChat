import React, { useMemo, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  FlatList,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  SafeAreaView,
  ScrollView,
  StatusBar,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';

type UserProfile = {
  id: string;
  display_name: string;
  mobile?: string;
  role?: string;
};

type AppSession = {
  access_token: string;
  refresh_token: string;
  user: UserProfile;
};

type RequestCodeResult = {
  status: string;
  account_exists: boolean;
  dev_code?: string;
};

type ChatGroup = {
  id: string;
  title: string;
  description?: string;
  visibility: string;
  member_count?: number;
  my_role?: string;
};

type ChatMessage = {
  id: string;
  group_id: string;
  sender_id: string;
  sender_name: string;
  text: string;
  created_at: string;
};

const API_BASE_URL = (process.env.EXPO_PUBLIC_API_BASE_URL || 'http://localhost:8080').replace(/\/$/, '');

function toErrorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  return String(error);
}

async function apiRequest<T>(path: string, options: RequestInit = {}, token?: string): Promise<T> {
  const headers = new Headers(options.headers);
  headers.set('Content-Type', 'application/json');
  if (token) headers.set('Authorization', `Bearer ${token}`);

  const response = await fetch(`${API_BASE_URL}${path}`, { ...options, headers });
  const text = await response.text();
  const data = text ? JSON.parse(text) : null;

  if (!response.ok) {
    const message = data && typeof data.error === 'string' ? data.error : `Server error ${response.status}`;
    throw new Error(message);
  }

  return data as T;
}

export default function App() {
  const [mobile, setMobile] = useState('+996');
  const [code, setCode] = useState('');
  const [displayName, setDisplayName] = useState('');
  const [devCode, setDevCode] = useState<string | null>(null);
  const [session, setSession] = useState<AppSession | null>(null);
  const [groups, setGroups] = useState<ChatGroup[]>([]);
  const [selectedGroup, setSelectedGroup] = useState<ChatGroup | null>(null);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [newGroupTitle, setNewGroupTitle] = useState('');
  const [newGroupDescription, setNewGroupDescription] = useState('');
  const [messageText, setMessageText] = useState('');
  const [loading, setLoading] = useState(false);

  const token = session?.access_token;
  const isAdmin = useMemo(() => session?.user.role === 'platform_admin' || session?.user.role === 'super_admin', [session]);

  async function run(action: () => Promise<void>) {
    try {
      setLoading(true);
      await action();
    } catch (error) {
      Alert.alert('KOOM', toErrorMessage(error));
    } finally {
      setLoading(false);
    }
  }

  async function requestCode() {
    await run(async () => {
      const result = await apiRequest<RequestCodeResult>('/api/auth/request-code', {
        method: 'POST',
        body: JSON.stringify({ mobile: mobile.trim() }),
      });
      setDevCode(result.dev_code || null);
      if (result.dev_code) setCode(result.dev_code);
      Alert.alert('Code requested', result.dev_code ? `Development code: ${result.dev_code}` : 'Check SMS code.');
    });
  }

  async function verifyCode() {
    await run(async () => {
      const result = await apiRequest<AppSession>('/api/auth/verify-code', {
        method: 'POST',
        body: JSON.stringify({
          mobile: mobile.trim(),
          code: code.trim(),
          display_name: displayName.trim() || 'KOOM User',
        }),
      });
      setSession(result);
      await loadGroups(result.access_token);
    });
  }

  async function loadGroups(accessToken = token) {
    if (!accessToken) return;
    const result = await apiRequest<ChatGroup[]>('/api/groups', { method: 'GET' }, accessToken);
    setGroups(result);
  }

  async function createGroup() {
    await run(async () => {
      if (!token) throw new Error('Please sign in first.');
      if (!newGroupTitle.trim()) throw new Error('Group title is required.');
      await apiRequest<ChatGroup>('/api/groups', {
        method: 'POST',
        body: JSON.stringify({
          title: newGroupTitle.trim(),
          description: newGroupDescription.trim(),
          visibility: 'public',
        }),
      }, token);
      setNewGroupTitle('');
      setNewGroupDescription('');
      await loadGroups(token);
    });
  }

  async function openGroup(group: ChatGroup) {
    await run(async () => {
      if (!token) throw new Error('Please sign in first.');
      setSelectedGroup(group);
      const result = await apiRequest<ChatMessage[]>(`/api/groups/${group.id}/messages?limit=50`, { method: 'GET' }, token);
      setMessages(result.reverse());
    });
  }

  async function sendMessage() {
    await run(async () => {
      if (!token) throw new Error('Please sign in first.');
      if (!selectedGroup) throw new Error('Select a group first.');
      if (!messageText.trim()) throw new Error('Message is empty.');
      await apiRequest<ChatMessage>(`/api/groups/${selectedGroup.id}/messages`, {
        method: 'POST',
        body: JSON.stringify({ text: messageText.trim() }),
      }, token);
      setMessageText('');
      await openGroup(selectedGroup);
    });
  }

  if (!session) {
    return (
      <SafeAreaView style={styles.safeArea}>
        <StatusBar barStyle="dark-content" />
        <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={styles.container}>
          <View style={styles.header}>
            <Text style={styles.logo}>KOOM</Text>
            <Text style={styles.subtitle}>Expo Go client connected to the existing Koom Server API.</Text>
            <Text style={styles.apiUrl}>API: {API_BASE_URL}</Text>
          </View>

          <View style={styles.card}>
            <Text style={styles.label}>Phone number</Text>
            <TextInput value={mobile} onChangeText={setMobile} keyboardType="phone-pad" autoCapitalize="none" style={styles.input} />
            <Text style={styles.label}>Display name</Text>
            <TextInput value={displayName} onChangeText={setDisplayName} placeholder="Your name" style={styles.input} />
            <Pressable onPress={requestCode} style={styles.primaryButton} disabled={loading}>
              <Text style={styles.primaryButtonText}>Request code</Text>
            </Pressable>
            {devCode ? <Text style={styles.devCode}>Dev code: {devCode}</Text> : null}
            <Text style={styles.label}>Code</Text>
            <TextInput value={code} onChangeText={setCode} keyboardType="number-pad" style={styles.input} />
            <Pressable onPress={verifyCode} style={styles.secondaryButton} disabled={loading}>
              <Text style={styles.secondaryButtonText}>Sign in</Text>
            </Pressable>
          </View>
          {loading ? <ActivityIndicator style={styles.loader} /> : null}
        </KeyboardAvoidingView>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.safeArea}>
      <StatusBar barStyle="dark-content" />
      <View style={styles.container}>
        <View style={styles.topBar}>
          <View>
            <Text style={styles.logo}>KOOM</Text>
            <Text style={styles.subtitle}>Signed in as {session.user.display_name}</Text>
            {isAdmin ? <Text style={styles.adminBadge}>Platform admin</Text> : null}
          </View>
          <Pressable onPress={() => setSession(null)} style={styles.logoutButton}>
            <Text style={styles.logoutText}>Logout</Text>
          </Pressable>
        </View>

        <ScrollView showsVerticalScrollIndicator={false}>
          <View style={styles.card}>
            <Text style={styles.sectionTitle}>Create public group</Text>
            <TextInput value={newGroupTitle} onChangeText={setNewGroupTitle} placeholder="Group title" style={styles.input} />
            <TextInput value={newGroupDescription} onChangeText={setNewGroupDescription} placeholder="Description" style={styles.input} />
            <Pressable onPress={createGroup} style={styles.primaryButton} disabled={loading}>
              <Text style={styles.primaryButtonText}>Create group</Text>
            </Pressable>
          </View>

          <View style={styles.card}>
            <View style={styles.rowBetween}>
              <Text style={styles.sectionTitle}>Groups</Text>
              <Pressable onPress={() => run(() => loadGroups())} disabled={loading}>
                <Text style={styles.link}>Refresh</Text>
              </Pressable>
            </View>
            <FlatList
              data={groups}
              keyExtractor={(item) => item.id}
              scrollEnabled={false}
              ListEmptyComponent={<Text style={styles.muted}>No groups yet.</Text>}
              renderItem={({ item }) => (
                <Pressable onPress={() => openGroup(item)} style={styles.groupItem}>
                  <Text style={styles.groupTitle}>{item.title}</Text>
                  <Text style={styles.muted}>{item.description || 'No description'} · {item.visibility}</Text>
                </Pressable>
              )}
            />
          </View>

          {selectedGroup ? (
            <View style={styles.card}>
              <Text style={styles.sectionTitle}>{selectedGroup.title}</Text>
              {messages.length === 0 ? <Text style={styles.muted}>No messages yet.</Text> : null}
              {messages.map((message) => (
                <View key={message.id} style={styles.messageBubble}>
                  <Text style={styles.messageAuthor}>{message.sender_name}</Text>
                  <Text style={styles.messageText}>{message.text}</Text>
                </View>
              ))}
              <TextInput value={messageText} onChangeText={setMessageText} placeholder="Write a message" style={styles.input} />
              <Pressable onPress={sendMessage} style={styles.secondaryButton} disabled={loading}>
                <Text style={styles.secondaryButtonText}>Send</Text>
              </Pressable>
            </View>
          ) : null}
        </ScrollView>
        {loading ? <ActivityIndicator style={styles.loader} /> : null}
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: '#f4f7fb',
  },
  container: {
    flex: 1,
    padding: 20,
  },
  header: {
    marginTop: 24,
    marginBottom: 24,
  },
  topBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 16,
  },
  logo: {
    fontSize: 34,
    fontWeight: '800',
    color: '#10233f',
  },
  subtitle: {
    marginTop: 4,
    color: '#526275',
    fontSize: 15,
  },
  apiUrl: {
    marginTop: 8,
    color: '#667085',
    fontSize: 12,
  },
  card: {
    backgroundColor: 'white',
    borderRadius: 22,
    padding: 18,
    marginBottom: 16,
    shadowColor: '#101828',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.08,
    shadowRadius: 18,
    elevation: 3,
  },
  sectionTitle: {
    fontSize: 19,
    fontWeight: '700',
    color: '#10233f',
    marginBottom: 12,
  },
  label: {
    fontSize: 13,
    fontWeight: '600',
    color: '#526275',
    marginBottom: 6,
    marginTop: 10,
  },
  input: {
    borderWidth: 1,
    borderColor: '#d0d5dd',
    borderRadius: 14,
    paddingHorizontal: 14,
    paddingVertical: 12,
    fontSize: 16,
    backgroundColor: '#fff',
    marginBottom: 12,
  },
  primaryButton: {
    backgroundColor: '#155eef',
    borderRadius: 14,
    paddingVertical: 14,
    alignItems: 'center',
    marginTop: 4,
  },
  primaryButtonText: {
    color: 'white',
    fontSize: 16,
    fontWeight: '700',
  },
  secondaryButton: {
    backgroundColor: '#ecf2ff',
    borderRadius: 14,
    paddingVertical: 14,
    alignItems: 'center',
    marginTop: 4,
  },
  secondaryButtonText: {
    color: '#155eef',
    fontSize: 16,
    fontWeight: '700',
  },
  logoutButton: {
    paddingHorizontal: 14,
    paddingVertical: 10,
    borderRadius: 12,
    backgroundColor: '#fff',
  },
  logoutText: {
    color: '#d92d20',
    fontWeight: '700',
  },
  loader: {
    marginTop: 14,
  },
  devCode: {
    marginTop: 12,
    color: '#027a48',
    fontWeight: '700',
  },
  adminBadge: {
    alignSelf: 'flex-start',
    marginTop: 6,
    paddingHorizontal: 8,
    paddingVertical: 4,
    backgroundColor: '#e0f2fe',
    color: '#026aa2',
    borderRadius: 8,
    fontSize: 12,
    fontWeight: '700',
  },
  rowBetween: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  link: {
    color: '#155eef',
    fontWeight: '700',
  },
  muted: {
    color: '#667085',
  },
  groupItem: {
    paddingVertical: 14,
    borderTopWidth: 1,
    borderTopColor: '#eef2f6',
  },
  groupTitle: {
    color: '#10233f',
    fontSize: 16,
    fontWeight: '700',
    marginBottom: 4,
  },
  messageBubble: {
    backgroundColor: '#f2f4f7',
    borderRadius: 14,
    padding: 12,
    marginBottom: 10,
  },
  messageAuthor: {
    color: '#344054',
    fontWeight: '700',
    marginBottom: 4,
  },
  messageText: {
    color: '#10233f',
    fontSize: 15,
  },
});
