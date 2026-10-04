import {
  Action,
  ActionPanel,
  Form,
  Icon,
  Keyboard,
  LaunchProps,
  List,
  PopToRootType,
  closeMainWindow,
  getPreferenceValues,
  open,
  showToast,
  Toast,
  useNavigation,
} from "@raycast/api";
import { useEffect, useRef, useState } from "react";
import { App, Settings, applySettings, decisive, key, matches } from "./model";
import {
  createFocusGuard,
  loadApps,
  loadSettings,
  refreshApps,
  saveSettings,
} from "./store";

function Rename({ app, save }: { app: App; save: (name: string) => void }) {
  const { pop } = useNavigation();
  return (
    <Form
      navigationTitle={`Rename ${app.originalName}`}
      actions={
        <ActionPanel>
          <Action.SubmitForm
            title="Save Name"
            onSubmit={(values: { name: string }) => {
              save(values.name);
              pop();
            }}
          />
        </ActionPanel>
      }
    >
      <Form.TextField
        id="name"
        title="Launcher Name"
        defaultValue={app.name}
        placeholder={app.originalName}
      />
      <Form.Description text="Leave empty to restore the original name. The application itself is unchanged." />
    </Form>
  );
}

export default function Browser({
  manage = false,
  fallbackText = "",
}: {
  manage?: boolean;
  fallbackText?: LaunchProps["fallbackText"];
}) {
  const { push } = useNavigation();
  const [apps, setApps] = useState(loadApps);
  const [settings, setSettings] = useState<Settings>(
    () => loadSettings() ?? { aliases: {}, hidden: [], recent: {} },
  );
  const [ready, setReady] = useState(
    () => !!loadSettings() && loadApps().length > 0,
  );
  const [loading, setLoading] = useState(true);
  const [query, setQuery] = useState(fallbackText);
  const [paused, setPaused] = useState(false);
  const settingsRef = useRef(settings);
  settingsRef.current = settings;
  const pending = useRef<{
    timer?: ReturnType<typeof setTimeout>;
    abort?: AbortController;
    generation: number;
  }>({ generation: 0 });
  const focusGuard = useRef<ReturnType<typeof createFocusGuard> | undefined>(
    undefined,
  );
  const launching = useRef(false);
  const alive = useRef(true);
  const auto = getPreferenceValues<{ autoLaunch: boolean }>().autoLaunch;
  const results = matches(
    query,
    applySettings(apps, settings, manage),
    manage ? Infinity : 6,
  );

  function cancel() {
    pending.current.generation++;
    clearTimeout(pending.current.timer);
    pending.current.abort?.abort();
  }
  function update(next: Settings) {
    cancel();
    saveSettings(next);
    settingsRef.current = next;
    setSettings(next);
  }
  async function refresh() {
    cancel();
    setLoading(true);
    try {
      const snapshot = await refreshApps();
      if (!alive.current) return;
      setApps(snapshot.apps);
      setSettings(snapshot.settings);
      setReady(true);
      if (snapshot.failures.length)
        await showToast({
          style: Toast.Style.Failure,
          title: "Some applications could not be refreshed",
          message:
            "Previous results have been retained. Try Refresh Applications.",
        });
    } catch (error) {
      await showToast({
        style: Toast.Style.Failure,
        title: "Could not refresh applications",
        message: String(error),
      });
    } finally {
      if (alive.current) setLoading(false);
    }
  }
  useEffect(() => {
    alive.current = true;
    focusGuard.current = createFocusGuard();
    void refresh();
    return () => {
      alive.current = false;
      cancel();
      focusGuard.current?.close();
    };
  }, []);

  async function launch(app: App) {
    cancel();
    if (launching.current) return;
    launching.current = true;
    try {
      await open(app.path);
      const current = settingsRef.current;
      saveSettings({
        ...current,
        recent: { ...current.recent, [key(app)]: Date.now() / 1000 },
      });
      await closeMainWindow({
        clearRootSearch: true,
        popToRootType: PopToRootType.Immediate,
      });
    } catch (error) {
      launching.current = false;
      await showToast({
        style: Toast.Style.Failure,
        title: `Could not open ${app.name}`,
        message: String(error),
      });
    }
  }
  function search(text: string) {
    cancel();
    setQuery(text);
    if (manage || !auto || paused || !ready || launching.current) return;
    const candidate = decisive(
      text,
      matches(text, applySettings(apps, settingsRef.current)),
    );
    if (!candidate) return;
    const generation = pending.current.generation;
    const abort = new AbortController();
    pending.current.abort = abort;
    pending.current.timer = setTimeout(async () => {
      try {
        const front = await focusGuard.current?.check(abort.signal);
        if (front && alive.current && generation === pending.current.generation)
          await launch(candidate);
      } catch (error) {
        if (!abort.signal.aborted)
          console.error("Auto-open focus check failed", error);
      }
    }, 90);
  }
  function rename(app: App) {
    cancel();
    push(
      <Rename
        app={app}
        save={(name) => {
          const aliases = { ...settingsRef.current.aliases };
          if (name.trim() && name.trim() !== app.originalName)
            aliases[key(app)] = name.trim();
          else delete aliases[key(app)];
          update({ ...settingsRef.current, aliases });
        }}
      />,
    );
  }
  function toggleHidden(app: App) {
    const current = settingsRef.current;
    update({
      ...current,
      hidden: current.hidden.includes(key(app))
        ? current.hidden.filter((k) => k !== key(app))
        : [...current.hidden, key(app)],
    });
  }
  const sharedActions = (
    <>
      {!manage && (
        <Action
          title="Manage Applications"
          icon={Icon.Gear}
          shortcut={{ modifiers: ["cmd", "shift"], key: "m" }}
          onAction={() => {
            cancel();
            push(<Browser manage />);
          }}
        />
      )}
      <Action
        title="Refresh Applications"
        icon={Icon.ArrowClockwise}
        shortcut={{ modifiers: ["cmd", "shift"], key: "r" }}
        onAction={() => void refresh()}
      />
      {!manage && (
        <Action
          title={
            paused ? "Resume Automatic Opening" : "Pause Automatic Opening"
          }
          icon={Icon.Pause}
          shortcut={{ modifiers: ["cmd", "shift"], key: "p" }}
          onAction={() => {
            cancel();
            setPaused(!paused);
          }}
        />
      )}
    </>
  );
  return (
    <List
      navigationTitle={
        manage
          ? "Manage Launcher Applications"
          : `Launcher${paused ? " · Auto-open paused" : ""}`
      }
      searchBarPlaceholder={
        manage
          ? "Find apps to rename, hide or restore…"
          : "Open an application…"
      }
      filtering={false}
      throttle={false}
      isLoading={loading}
      searchText={query}
      onSearchTextChange={search}
      onSelectionChange={(id) => {
        if (id && id !== results[0]?.app.path) cancel();
      }}
      actions={<ActionPanel>{sharedActions}</ActionPanel>}
    >
      <List.EmptyView
        title={loading ? "Loading applications…" : "No matching applications"}
        description="Use Actions to refresh or manage hidden apps."
      />
      {results.map(({ app }, index) => (
        <List.Item
          key={app.path}
          id={app.path}
          title={app.name}
          subtitle={
            app.name !== app.originalName ? app.originalName : undefined
          }
          icon={{ fileIcon: app.path }}
          accessories={
            manage
              ? [
                  {
                    text: settings.hidden.includes(key(app))
                      ? "Hidden"
                      : "Visible",
                  },
                ]
              : [{ text: `⌘${index + 1}` }]
          }
          actions={
            <ActionPanel>
              <Action
                title="Open Application"
                icon={Icon.AppWindow}
                onAction={() => void launch(app)}
              />
              <Action
                title="Rename Application"
                icon={Icon.Pencil}
                shortcut={{ modifiers: ["cmd"], key: "r" }}
                onAction={() => rename(app)}
              />
              <Action
                title={
                  settings.hidden.includes(key(app))
                    ? "Restore to Launcher"
                    : "Hide from Launcher"
                }
                icon={Icon.Eye}
                onAction={() => toggleHidden(app)}
              />
              {!manage && (
                <ActionPanel.Section title="Open by Position">
                  {results.map(({ app: target }, i) => (
                    <Action
                      key={target.path}
                      title={`Open ${target.name}`}
                      shortcut={{
                        modifiers: ["cmd"],
                        key: String(i + 1) as Keyboard.KeyEquivalent,
                      }}
                      onAction={() => void launch(target)}
                    />
                  ))}
                </ActionPanel.Section>
              )}
              <ActionPanel.Section>{sharedActions}</ActionPanel.Section>
            </ActionPanel>
          }
        />
      ))}
    </List>
  );
}
