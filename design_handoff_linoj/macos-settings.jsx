// ===============================================================
// Settings — macOS modal + iOS screen
// Appearance is hard-locked to System. Everything else is real prefs.
// ===============================================================

// ── macOS Settings (modal, sidebar nav) ──
function ASettingsView({ mode = 'light', section = 'general' }) {
  const t = A_TOKENS[mode];
  const sections = [
    { key: 'general', label: 'General' },
    { key: 'notifications', label: 'Notifications' },
    { key: 'sync', label: 'Sync' },
    { key: 'shortcuts', label: 'Shortcuts' },
    { key: 'about', label: 'About' },
  ];

  return (
    <div style={{
      position: 'absolute', inset: 0,
      background: 'rgba(0,0,0,0.42)',
      backdropFilter: 'blur(2px)',
      display: 'flex', alignItems: 'flex-start', justifyContent: 'center',
      paddingTop: 96, zIndex: 100,
    }}>
      <div style={{
        width: 760, height: 540,
        background: t.panel, color: t.ink,
        borderRadius: 14,
        boxShadow: '0 24px 80px rgba(0,0,0,0.45), 0 0 0 0.5px rgba(0,0,0,0.18)',
        overflow: 'hidden', display: 'flex',
        fontFamily: A_FONT,
      }}>
        {/* Sidebar */}
        <div style={{
          width: 188, flexShrink: 0,
          background: t.bgSoft,
          borderRight: `0.5px solid ${t.border}`,
          padding: '12px 8px',
          display: 'flex', flexDirection: 'column', gap: 2,
        }}>
          <div style={{
            padding: '6px 10px 14px', display: 'flex', alignItems: 'center', gap: 8,
          }}>
            <ATrafficLights mode={mode}/>
            <div style={{
              fontFamily: A_DISPLAY, fontSize: 13, fontWeight: 600,
              letterSpacing: '-0.01em', color: t.ink, marginLeft: 4,
            }}>Settings</div>
          </div>
          {sections.map(s => {
            const isActive = s.key === section;
            return (
              <button key={s.key} style={{
                display: 'flex', alignItems: 'center', gap: 8,
                padding: '6px 10px', borderRadius: 6,
                background: isActive ? t.chip : 'transparent',
                color: isActive ? t.ink : t.inkSoft,
                border: 'none', cursor: 'pointer',
                fontSize: 12.5, fontWeight: isActive ? 600 : 500,
                fontFamily: A_FONT, textAlign: 'left',
              }}>{s.label}</button>
            );
          })}
        </div>

        {/* Content */}
        <div style={{ flex: 1, overflow: 'auto', padding: '20px 28px 28px' }}>
          {section === 'general' && <ASettingsGeneral t={t} mode={mode}/>}
          {section === 'notifications' && <ASettingsNotifications t={t} mode={mode}/>}
          {section === 'sync' && <ASettingsSync t={t} mode={mode}/>}
          {section === 'shortcuts' && <ASettingsShortcuts t={t} mode={mode}/>}
          {section === 'about' && <ASettingsAbout t={t} mode={mode}/>}
        </div>
      </div>
    </div>
  );
}

function ASettingsHeader({ label, hint }) {
  return (
    <div style={{ marginBottom: 18 }}>
      <div style={{
        fontFamily: A_DISPLAY, fontSize: 19, fontWeight: 600,
        letterSpacing: '-0.02em',
      }}>{label}</div>
      {hint && (
        <div style={{
          fontSize: 12.5, marginTop: 4, fontWeight: 500,
          color: 'rgba(10,10,10,0.62)',
        }}>{hint}</div>
      )}
    </div>
  );
}

function ARow({ label, hint, control, t }) {
  return (
    <div style={{
      display: 'grid', gridTemplateColumns: '1fr auto', gap: 16,
      alignItems: 'center',
      padding: '12px 0',
      borderTop: `0.5px solid ${t.border}`,
    }}>
      <div>
        <div style={{
          fontSize: 13, fontWeight: 500, color: t.ink,
          letterSpacing: '-0.005em',
        }}>{label}</div>
        {hint && (
          <div style={{
            fontSize: 11.5, color: t.inkMute, marginTop: 3, fontWeight: 500,
          }}>{hint}</div>
        )}
      </div>
      <div>{control}</div>
    </div>
  );
}

function ASettingsGeneral({ t, mode }) {
  return (
    <div>
      <ASettingsHeader label="General" hint="The basics."/>
      <ARow t={t}
        label="Appearance"
        hint="Follows your system. Switch in macOS Settings to change."
        control={
          <div style={{
            display: 'flex', alignItems: 'center', gap: 6,
            padding: '4px 10px', borderRadius: 7,
            background: t.chip,
            fontSize: 12, fontWeight: 600, color: t.inkSoft,
          }}>
            <svg width="10" height="10" viewBox="0 0 10 10" fill="none">
              <circle cx="5" cy="5" r="3.5" stroke="currentColor" strokeWidth="1.2"/>
              <path d="M5 1.5v7" stroke="currentColor" strokeWidth="1.2"/>
            </svg>
            System
            <kbd style={{
              fontFamily: A_MONO, fontSize: 9.5, color: t.inkDim,
              padding: '0 4px', marginLeft: 4,
            }}>locked</kbd>
          </div>
        }/>
      <ARow t={t}
        label="Default tab on launch"
        hint="Which board opens when you start LinoJ."
        control={<ASelect value="Main" t={t} mode={mode}/>}/>
      <ARow t={t}
        label="Default scope for new todos"
        hint="Personal or Company \u2014 you can change per item."
        control={<ASelect value="Company" t={t} mode={mode}/>}/>
      <ARow t={t}
        label="Show completed in counts"
        hint="Whether done items still count toward the open total."
        control={<AToggle on={false} t={t}/>}/>
      <ARow t={t}
        label="Start week on"
        hint="Calendar week-view origin."
        control={<ASelect value="Today" t={t} mode={mode}/>}/>
    </div>
  );
}

function ASettingsNotifications({ t, mode }) {
  return (
    <div>
      <ASettingsHeader label="Notifications" hint="Heads-ups about events. Todos never bug you on a clock."/>
      <ARow t={t}
        label="Heads-up before each event"
        hint="A soft banner appears on Main this far before an event starts."
        control={<ASelect value="30 minutes" t={t} mode={mode}/>}/>
      <ARow t={t}
        label="System notification too"
        hint="In addition to the in-app banner, ping macOS Notification Center."
        control={<AToggle on={true} t={t}/>}/>
      <ARow t={t}
        label="Yesterday's missed events"
        hint="Show a small \u201cFrom yesterday\u201d card on Main to confirm attendance."
        control={<AToggle on={true} t={t}/>}/>
      <ARow t={t}
        label="Daily summary"
        hint="A quick read of today's load, delivered each morning."
        control={<ASelect value="8:00 AM" t={t} mode={mode}/>}/>
      <ARow t={t}
        label="Quiet hours"
        hint="Don't pop up between these times."
        control={
          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <ASelect value="10 PM" t={t} mode={mode} mono/>
            <span style={{ fontSize: 11, color: t.inkMute }}>\u2014</span>
            <ASelect value="7 AM" t={t} mode={mode} mono/>
          </div>
        }/>
    </div>
  );
}

function ASettingsSync({ t, mode }) {
  return (
    <div>
      <ASettingsHeader label="Sync" hint="Keep LinoJ in lockstep across your devices."/>
      <ARow t={t}
        label="iCloud sync"
        hint="Required if you also use LinoJ on iPhone."
        control={<AToggle on={true} t={t}/>}/>
      <ARow t={t}
        label="Account"
        hint="lin@example.com"
        control={
          <button style={{
            background: 'transparent', border: `0.5px solid ${t.borderStrong}`,
            color: t.inkSoft, cursor: 'pointer',
            fontSize: 11.5, fontWeight: 500, fontFamily: A_FONT,
            padding: '4px 10px', borderRadius: 6,
          }}>Sign out</button>
        }/>
      <ARow t={t}
        label="Sync to Apple Calendar"
        hint="Mirror LinoJ events as a separate calendar in Calendar.app."
        control={<AToggle on={false} t={t}/>}/>
      <ARow t={t}
        label="Sync to Apple Reminders"
        hint="Mirror todos as a separate list in Reminders.app."
        control={<AToggle on={false} t={t}/>}/>
      <div style={{
        marginTop: 18,
        padding: '10px 12px', borderRadius: 8,
        background: t.chip,
        fontSize: 11.5, color: t.inkSoft, fontWeight: 500,
        display: 'flex', alignItems: 'center', gap: 8,
      }}>
        <div style={{
          width: 6, height: 6, borderRadius: '50%', background: '#19c332',
        }}/>
        Last synced just now \u00b7 3 devices
      </div>
    </div>
  );
}

function ASettingsShortcuts({ t, mode }) {
  const groups = [
    {
      label: 'Navigation',
      items: [
        ['\u2318 1', 'Main'],
        ['\u2318 2', 'Personal'],
        ['\u2318 3', 'Company'],
        ['\u2318 4', 'Calendar'],
        ['\u2318 K', 'Open search / jump'],
        ['\u2318 ,', 'Open Settings'],
      ],
    },
    {
      label: 'Create',
      items: [
        ['\u2318 N', 'New (defaults to Todo)'],
        ['\u2318 \u21E7 T', 'New Todo'],
        ['\u2318 \u21E7 E', 'New Event'],
        ['\u2318 \u21E7 P', 'New Project'],
      ],
    },
    {
      label: 'On a todo',
      items: [
        ['\u2318 \u23CE', 'Toggle done'],
        ['\u2318 U', 'Toggle Urgent / Normal'],
        ['\u232B', 'Delete'],
      ],
    },
  ];
  return (
    <div>
      <ASettingsHeader label="Shortcuts" hint="Cheat sheet. All editable in the next release."/>
      {groups.map((g, gi) => (
        <div key={g.label} style={{ marginBottom: gi < groups.length - 1 ? 22 : 0 }}>
          <div style={{
            fontSize: 11, fontWeight: 700, color: t.inkMute,
            textTransform: 'uppercase', letterSpacing: '0.08em',
            marginBottom: 8,
          }}>{g.label}</div>
          <div style={{
            background: t.bgSoft, borderRadius: 8,
            border: `0.5px solid ${t.border}`,
            overflow: 'hidden',
          }}>
            {g.items.map(([keys, label], i) => (
              <div key={i} style={{
                display: 'grid', gridTemplateColumns: '120px 1fr',
                alignItems: 'center', gap: 16,
                padding: '8px 14px',
                borderTop: i === 0 ? 'none' : `0.5px solid ${t.border}`,
              }}>
                <kbd style={{
                  fontFamily: A_MONO, fontSize: 11.5, fontWeight: 600,
                  color: t.ink, letterSpacing: '0.04em',
                }}>{keys}</kbd>
                <div style={{ fontSize: 12.5, color: t.inkSoft, fontWeight: 500 }}>
                  {label}
                </div>
              </div>
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}

function ASettingsAbout({ t, mode }) {
  return (
    <div>
      <ASettingsHeader label="About"/>
      <div style={{
        display: 'flex', flexDirection: 'column', gap: 6,
        marginBottom: 22,
      }}>
        <div style={{
          fontFamily: A_DISPLAY, fontSize: 22, fontWeight: 600,
          letterSpacing: '-0.025em',
        }}>LinoJ</div>
        <div style={{ fontSize: 13, color: t.inkSoft, fontWeight: 500 }}>
          A calm planner. Personal, Company, Calendar \u2014 untangled.
        </div>
        <div style={{
          fontFamily: A_MONO, fontSize: 11.5, color: t.inkMute, marginTop: 4,
        }}>v1.0.0 (build 240)</div>
      </div>
      {[
        ['Release notes', 'See what changed.'],
        ['Send feedback', 'feedback@linoj.app'],
        ['Privacy policy', 'How LinoJ handles your data.'],
        ['Acknowledgements', 'People and open-source projects.'],
      ].map(([label, hint], i) => (
        <div key={i} style={{
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          padding: '12px 0',
          borderTop: `0.5px solid ${t.border}`,
          cursor: 'pointer',
        }}>
          <div>
            <div style={{ fontSize: 13, fontWeight: 500, color: t.ink }}>{label}</div>
            <div style={{ fontSize: 11.5, color: t.inkMute, marginTop: 2, fontWeight: 500 }}>{hint}</div>
          </div>
          <svg width="8" height="12" viewBox="0 0 8 12" fill="none">
            <path d="M2 2l4 4-4 4" stroke={t.inkDim} strokeWidth="1.4"
              fill="none" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>
        </div>
      ))}
    </div>
  );
}

// ── Form primitives ──
function AToggle({ on, t }) {
  return (
    <div style={{
      width: 38, height: 22, borderRadius: 11,
      background: on ? t.ink : t.chip,
      position: 'relative', cursor: 'pointer',
      transition: 'background 0.15s',
      border: on ? 'none' : `0.5px solid ${t.border}`,
    }}>
      <div style={{
        position: 'absolute', top: 2, left: on ? 18 : 2,
        width: 18, height: 18, borderRadius: '50%',
        background: on ? t.bg : t.panel,
        boxShadow: '0 1px 3px rgba(0,0,0,0.18)',
        transition: 'left 0.18s',
      }}/>
    </div>
  );
}

function ASelect({ value, t, mode, mono }) {
  return (
    <div style={{
      display: 'inline-flex', alignItems: 'center', gap: 8,
      padding: '4px 8px 4px 10px',
      background: t.chip, borderRadius: 7,
      fontFamily: mono ? A_MONO : A_FONT,
      fontSize: 12, fontWeight: 500, color: t.ink,
      cursor: 'pointer',
      border: `0.5px solid ${t.border}`,
    }}>
      {value}
      <svg width="9" height="9" viewBox="0 0 9 9" fill="none">
        <path d="M2 3l2.5 3 2.5-3" stroke="currentColor" strokeWidth="1.4"
          fill="none" strokeLinecap="round" strokeLinejoin="round"/>
      </svg>
    </div>
  );
}

Object.assign(window, {
  ASettingsView, ASettingsHeader, ARow, AToggle, ASelect,
});
