// ===============================================================
// Overlays — New & Search for macOS and iOS
// ===============================================================

// ── Type icons ──
function IconType({ kind, size = 14, color = 'currentColor' }) {
  if (kind === 'todo') return (
    <svg width={size} height={size} viewBox="0 0 14 14" fill="none">
      <rect x="2" y="2" width="10" height="10" rx="2.5" stroke={color} strokeWidth="1.3"/>
    </svg>
  );
  if (kind === 'event') return (
    <svg width={size} height={size} viewBox="0 0 14 14" fill="none">
      <rect x="2" y="3" width="10" height="9" rx="2" stroke={color} strokeWidth="1.3"/>
      <line x1="2" y1="6" x2="12" y2="6" stroke={color} strokeWidth="1.1"/>
      <line x1="4.5" y1="1.5" x2="4.5" y2="4" stroke={color} strokeWidth="1.3" strokeLinecap="round"/>
      <line x1="9.5" y1="1.5" x2="9.5" y2="4" stroke={color} strokeWidth="1.3" strokeLinecap="round"/>
    </svg>
  );
  if (kind === 'project') return (
    <svg width={size} height={size} viewBox="0 0 14 14" fill="none">
      <path d="M2 4.5h4l1.5 1.5h4.5V11a1 1 0 01-1 1H3a1 1 0 01-1-1V4.5z"
        stroke={color} strokeWidth="1.3" strokeLinejoin="round"/>
    </svg>
  );
  return null;
}

// ===============================================================
// macOS New (Quick add) modal
// ===============================================================
function ANewModal({ mode = 'light', kind = 'project' }) {
  const t = A_TOKENS[mode];
  const [activeKind, setActiveKind] = React.useState(kind);
  const [urgent, setUrgent] = React.useState(false);

  return (
    <div style={{
      position: 'absolute', inset: 0,
      background: 'rgba(0,0,0,0.42)',
      backdropFilter: 'blur(2px)',
      display: 'flex', alignItems: 'flex-start', justifyContent: 'center',
      paddingTop: 120, zIndex: 100,
    }}>
      <div style={{
        width: 520,
        background: t.panel,
        color: t.ink,
        borderRadius: 14,
        boxShadow: '0 24px 80px rgba(0,0,0,0.45), 0 0 0 0.5px rgba(0,0,0,0.18)',
        overflow: 'hidden',
        fontFamily: A_FONT,
      }}>
        {/* Header */}
        <div style={{
          display: 'flex', alignItems: 'center',
          padding: '14px 16px 12px',
          borderBottom: `0.5px solid ${t.border}`,
        }}>
          <div style={{
            fontFamily: A_DISPLAY, fontSize: 14, fontWeight: 600,
            letterSpacing: '-0.01em', color: t.ink,
          }}>New</div>
          <div style={{ flex: 1 }}/>
          <div style={{
            display: 'flex', gap: 2, padding: 2,
            background: t.chip, borderRadius: 8,
          }}>
            {[
              { key: 'todo', label: 'Todo' },
              { key: 'event', label: 'Event' },
              { key: 'project', label: 'Project' },
            ].map(opt => {
              const isActive = activeKind === opt.key;
              return (
                <button key={opt.key} onClick={() => setActiveKind(opt.key)}
                  style={{
                    background: isActive ? t.panel : 'transparent',
                    color: isActive ? t.ink : t.inkSoft,
                    border: 'none', cursor: 'pointer',
                    padding: '4px 12px', borderRadius: 6,
                    fontSize: 12, fontWeight: isActive ? 600 : 500,
                    fontFamily: A_FONT,
                    boxShadow: isActive ? '0 0.5px 2px rgba(0,0,0,0.08)' : 'none',
                    display: 'flex', alignItems: 'center', gap: 6,
                  }}>
                  <IconType kind={opt.key} size={12} color={isActive ? t.ink : t.inkMute}/>
                  {opt.label}
                </button>
              );
            })}
          </div>
        </div>

        {/* Body */}
        {activeKind === 'todo' && <ANewTodoBody t={t} urgent={urgent} setUrgent={setUrgent}/>}
        {activeKind === 'event' && <ANewEventBody t={t}/>}
        {activeKind === 'project' && <ANewProjectBody t={t}/>}

        {/* Footer */}
        <div style={{
          display: 'flex', alignItems: 'center',
          padding: '12px 16px',
          borderTop: `0.5px solid ${t.border}`,
          background: mode === 'light' ? '#fbfaf8' : '#0f0f10',
        }}>
          <div style={{
            fontSize: 11.5, color: t.inkMute, fontWeight: 500,
            display: 'flex', alignItems: 'center', gap: 8,
          }}>
            <kbd style={kbdStyle(t, mode)}>esc</kbd>cancel
            <span style={{ color: t.inkDim, margin: '0 4px' }}>·</span>
            <kbd style={kbdStyle(t, mode)}>⌘↵</kbd>create
          </div>
          <div style={{ flex: 1 }}/>
          <button style={{
            background: 'transparent', color: t.inkSoft,
            border: `0.5px solid ${t.borderStrong}`,
            cursor: 'pointer', padding: '6px 14px', borderRadius: 7,
            fontSize: 12.5, fontWeight: 600, fontFamily: A_FONT,
          }}>Cancel</button>
          <button style={{
            background: t.ink, color: t.bg, border: 'none', cursor: 'pointer',
            padding: '6px 16px', borderRadius: 7,
            fontSize: 12.5, fontWeight: 600, fontFamily: A_FONT,
            marginLeft: 8,
          }}>Create {activeKind}</button>
        </div>
      </div>
    </div>
  );
}

function kbdStyle(t, mode) {
  return {
    fontFamily: A_MONO, fontSize: 10.5, color: t.inkSoft,
    padding: '1px 6px', borderRadius: 3, marginRight: 4,
    background: mode === 'light' ? 'rgba(0,0,0,0.05)' : 'rgba(255,255,255,0.06)',
    fontWeight: 600,
  };
}

function ANewTodoBody({ t, urgent, setUrgent }) {
  return (
    <div style={{ padding: '18px 20px 20px', display: 'flex', flexDirection: 'column', gap: 14 }}>
      <input autoFocus placeholder="What needs to be done?"
        defaultValue="Outline Q3 retro doc"
        style={{
          background: 'transparent', border: 'none', outline: 'none',
          fontFamily: A_DISPLAY, fontSize: 22, fontWeight: 600,
          letterSpacing: '-0.025em', color: t.ink,
          padding: 0,
        }}/>
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
        <ChipToggle label="Urgent"
          active={urgent} onChange={() => setUrgent(!urgent)} t={t}
          activeColor="blue"/>
        <ChipToggle label="Normal"
          active={!urgent} onChange={() => setUrgent(false)} t={t}/>
        <div style={{ width: 1, alignSelf: 'stretch', background: t.border, margin: '0 4px' }}/>
        <Chip label="Personal" t={t}/>
        <Chip label="Work" t={t} active/>
        <div style={{ width: 1, alignSelf: 'stretch', background: t.border, margin: '0 4px' }}/>
        <Chip label="No project" t={t}/>
        <Chip label="LinoJ for macOS v1" t={t} active/>
        <Chip label="Onboarding redesign" t={t}/>
        <Chip label="Q3 planning" t={t}/>
      </div>
    </div>
  );
}

function ANewEventBody({ t }) {
  return (
    <div style={{ padding: '18px 20px 20px', display: 'flex', flexDirection: 'column', gap: 14 }}>
      <input placeholder="Event name"
        defaultValue="Q3 retro review"
        style={{
          background: 'transparent', border: 'none', outline: 'none',
          fontFamily: A_DISPLAY, fontSize: 22, fontWeight: 600,
          letterSpacing: '-0.025em', color: t.ink,
        }}/>
      {/* Time + location */}
      <div style={{
        display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8,
      }}>
        <Field t={t} label="Date" value="Fri, May 30"/>
        <Field t={t} label="Start" value="14:00" mono/>
        <Field t={t} label="End" value="15:00" mono/>
      </div>
      <Field t={t} label="Location" value="Conf Rm A" full/>
      <div>
        <div style={{
          fontSize: 11, fontWeight: 600, color: t.inkMute,
          textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: 8,
        }}>Attendees</div>
        <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
          {['M', 'A', 'J'].map((m, i) => (
            <div key={i} style={{
              display: 'flex', alignItems: 'center', gap: 6,
              padding: '3px 10px 3px 4px',
              background: t.chip, borderRadius: 999,
            }}>
              <AAvatar name={m} size={20} mode="light"/>
              <span style={{ fontSize: 12, fontWeight: 500 }}>{m}ei</span>
            </div>
          ))}
          <button style={{
            padding: '3px 10px', borderRadius: 999,
            border: `0.5px dashed ${t.borderStrong}`,
            background: 'transparent', color: t.inkSoft,
            fontSize: 12, fontWeight: 500, cursor: 'pointer',
            fontFamily: A_FONT,
          }}>+ Add</button>
        </div>
      </div>
      <Field t={t} label="Link to project" value="LinoJ for macOS v1" full optional/>
    </div>
  );
}

function ANewProjectBody({ t }) {
  return (
    <div style={{ padding: '18px 20px 20px', display: 'flex', flexDirection: 'column', gap: 14 }}>
      <input placeholder="Project name"
        defaultValue="Calendar v2"
        style={{
          background: 'transparent', border: 'none', outline: 'none',
          fontFamily: A_DISPLAY, fontSize: 22, fontWeight: 600,
          letterSpacing: '-0.025em', color: t.ink,
        }}/>
      <textarea
        defaultValue="Rebuild the week timeline to feel like a calm page, not a grid. Aim for cmd-K driven nav and tighter event creation."
        style={{
          background: 'transparent', border: 'none', outline: 'none',
          fontFamily: A_FONT, fontSize: 13, fontWeight: 500,
          color: t.inkSoft, lineHeight: 1.5,
          resize: 'none', minHeight: 56,
        }}/>
      <Field t={t} label="Tag" value="Shipping July" hint="Free-form status label"/>
      <div>
        <div style={{
          fontSize: 11, fontWeight: 600, color: t.inkMute,
          textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: 8,
        }}>Members</div>
        <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
          {['L', 'M'].map((m, i) => (
            <div key={i} style={{
              display: 'flex', alignItems: 'center', gap: 6,
              padding: '3px 10px 3px 4px',
              background: t.chip, borderRadius: 999,
            }}>
              <AAvatar name={m} size={20} mode="light"/>
              <span style={{ fontSize: 12, fontWeight: 500 }}>
                {m === 'L' ? 'Linus (you)' : 'Mei'}
              </span>
            </div>
          ))}
          <button style={{
            padding: '3px 10px', borderRadius: 999,
            border: `0.5px dashed ${t.borderStrong}`,
            background: 'transparent', color: t.inkSoft,
            fontSize: 12, fontWeight: 500, cursor: 'pointer',
            fontFamily: A_FONT,
          }}>+ Invite</button>
        </div>
      </div>
    </div>
  );
}

function Field({ t, label, value, full, optional, mono, hint }) {
  return (
    <div style={{ gridColumn: full ? '1 / -1' : 'auto' }}>
      <div style={{
        display: 'flex', alignItems: 'baseline', gap: 6,
        fontSize: 11, fontWeight: 600, color: t.inkMute,
        textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: 5,
      }}>
        <span>{label}</span>
        {optional && <span style={{ fontWeight: 500, opacity: 0.6 }}>· optional</span>}
      </div>
      <div style={{
        padding: '7px 10px', borderRadius: 7,
        background: t.chip,
        fontSize: 13, fontWeight: 500, color: t.ink,
        fontFamily: mono ? A_MONO : A_FONT,
        letterSpacing: mono ? '-0.01em' : '-0.005em',
        cursor: 'text',
        border: `0.5px solid transparent`,
      }}>{value}</div>
      {hint && (
        <div style={{
          fontSize: 11, color: t.inkMute, marginTop: 4, fontStyle: 'italic',
        }}>{hint}</div>
      )}
    </div>
  );
}

function Chip({ label, t, active }) {
  return (
    <button style={{
      padding: '4px 10px', borderRadius: 999,
      border: `0.5px solid ${active ? t.borderStrong : t.border}`,
      background: active ? t.chip : 'transparent',
      color: active ? t.ink : t.inkSoft,
      fontSize: 11.5, fontWeight: active ? 600 : 500,
      fontFamily: A_FONT, cursor: 'pointer',
      whiteSpace: 'nowrap',
    }}>{label}</button>
  );
}

function ChipToggle({ label, active, onChange, t, activeColor }) {
  const blueBg = activeColor === 'blue';
  return (
    <button onClick={onChange} style={{
      padding: '4px 11px', borderRadius: 999,
      border: `0.5px solid ${
        active
          ? (blueBg ? t.blueBorder : t.borderStrong)
          : t.border
      }`,
      background: active
        ? (blueBg ? t.blueSoft : t.chip)
        : 'transparent',
      color: active
        ? (blueBg ? t.blueInk : t.ink)
        : t.inkSoft,
      fontSize: 11.5, fontWeight: active ? 700 : 500,
      fontFamily: A_FONT, cursor: 'pointer',
      display: 'inline-flex', alignItems: 'center', gap: 5,
    }}>
      {blueBg && active && (
        <span style={{
          width: 6, height: 6, borderRadius: '50%', background: t.blue,
        }}/>
      )}
      {label}
    </button>
  );
}

// ===============================================================
// macOS Search / Command Palette
// ===============================================================
function ASearchPalette({ mode = 'light' }) {
  const t = A_TOKENS[mode];
  const groups = [
    {
      label: 'Quick actions',
      items: [
        { type: 'cmd', icon: 'todo', title: 'New todo "review draft"', hint: '⌘N then ⌘1' },
        { type: 'cmd', icon: 'event', title: 'New event…', hint: '⌘N then ⌘2' },
        { type: 'cmd', icon: 'project', title: 'New project…', hint: '⌘N then ⌘3' },
      ],
    },
    {
      label: 'Todos',
      items: [
        { type: 'todo', icon: 'todo', title: 'Review legal redlines', urgent: false, hint: 'Company · Standalone' },
        { type: 'todo', icon: 'todo', title: 'Review onboarding copy v2', urgent: true, hint: 'Onboarding redesign' },
      ],
    },
    {
      label: 'Events',
      items: [
        { type: 'event', icon: 'event', title: 'Design review — sidebar', hint: 'Today · 2 PM · Conf Rm A' },
      ],
    },
    {
      label: 'Projects',
      items: [
        { type: 'project', icon: 'project', title: 'LinoJ for macOS v1', hint: '5 todos · 2 events · 3 members' },
      ],
    },
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
        width: 620,
        background: t.panel, color: t.ink,
        borderRadius: 14,
        boxShadow: '0 24px 80px rgba(0,0,0,0.45), 0 0 0 0.5px rgba(0,0,0,0.18)',
        overflow: 'hidden', fontFamily: A_FONT,
      }}>
        {/* Search input */}
        <div style={{
          display: 'flex', alignItems: 'center', gap: 12,
          padding: '14px 18px',
          borderBottom: `0.5px solid ${t.border}`,
        }}>
          <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
            <circle cx="7" cy="7" r="4.5" stroke={t.inkSoft} strokeWidth="1.4"/>
            <path d="M10.3 10.3L14 14" stroke={t.inkSoft} strokeWidth="1.4" strokeLinecap="round"/>
          </svg>
          <input autoFocus defaultValue="review" placeholder="Search across todos, events, projects…"
            style={{
              flex: 1, background: 'transparent', border: 'none', outline: 'none',
              fontFamily: A_FONT, fontSize: 15, fontWeight: 500,
              color: t.ink, letterSpacing: '-0.005em',
            }}/>
          {/* Scope filters */}
          <div style={{ display: 'flex', gap: 4 }}>
            {['All', 'Todos', 'Events', 'Projects'].map((s, i) => (
              <span key={s} style={{
                padding: '3px 9px', borderRadius: 5,
                fontSize: 11, fontWeight: i === 0 ? 600 : 500,
                color: i === 0 ? t.ink : t.inkMute,
                background: i === 0 ? t.chip : 'transparent',
                cursor: 'pointer',
              }}>{s}</span>
            ))}
          </div>
          <kbd style={kbdStyle(t, mode)}>esc</kbd>
        </div>

        {/* Results */}
        <div style={{
          maxHeight: 440, overflow: 'auto', padding: '6px 0',
        }}>
          {groups.map((g, gi) => (
            <div key={g.label} style={{
              paddingBottom: 4, marginTop: gi === 0 ? 0 : 4,
            }}>
              <div style={{
                padding: '6px 16px 4px',
                fontSize: 10.5, fontWeight: 700, color: t.inkMute,
                textTransform: 'uppercase', letterSpacing: '0.08em',
              }}>{g.label}</div>
              {g.items.map((item, idx) => {
                const isFirst = gi === 0 && idx === 0;
                return (
                  <div key={idx} style={{
                    display: 'flex', alignItems: 'center', gap: 12,
                    padding: '8px 16px',
                    background: isFirst
                      ? (mode === 'light' ? 'rgba(0,0,0,0.04)' : 'rgba(255,255,255,0.05)')
                      : 'transparent',
                    cursor: 'pointer',
                  }}>
                    <div style={{
                      width: 26, height: 26, borderRadius: 6,
                      background: t.chip,
                      display: 'flex', alignItems: 'center', justifyContent: 'center',
                      color: t.inkSoft, flexShrink: 0,
                    }}>
                      <IconType kind={item.icon} size={13}/>
                    </div>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{
                        fontSize: 13.5,
                        fontWeight: item.urgent || isFirst ? 600 : 500,
                        color: item.urgent ? t.blueInk : t.ink,
                        letterSpacing: '-0.005em', lineHeight: 1.3,
                      }}>
                        {item.urgent && (
                          <span style={{
                            display: 'inline-block', width: 6, height: 6, borderRadius: '50%',
                            background: t.blue, marginRight: 6, verticalAlign: 'middle',
                          }}/>
                        )}
                        {item.title}
                      </div>
                      {item.hint && (
                        <div style={{
                          fontSize: 11, color: t.inkMute, marginTop: 2,
                        }}>{item.hint}</div>
                      )}
                    </div>
                    {isFirst && <kbd style={kbdStyle(t, mode)}>↵</kbd>}
                    {!isFirst && (
                      <div style={{
                        fontSize: 11, color: t.inkDim, fontWeight: 500,
                      }}>
                        {item.type === 'cmd' ? 'Run' : 'Open'}
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          ))}
        </div>

        {/* Footer hints */}
        <div style={{
          display: 'flex', alignItems: 'center', gap: 14,
          padding: '10px 16px',
          borderTop: `0.5px solid ${t.border}`,
          background: mode === 'light' ? '#fbfaf8' : '#0f0f10',
          fontSize: 11, color: t.inkMute, fontWeight: 500,
        }}>
          <span><kbd style={kbdStyle(t, mode)}>↑↓</kbd>navigate</span>
          <span><kbd style={kbdStyle(t, mode)}>↵</kbd>open</span>
          <span><kbd style={kbdStyle(t, mode)}>⌘↵</kbd>open in new pane</span>
          <span><kbd style={kbdStyle(t, mode)}>tab</kbd>switch scope</span>
          <div style={{ flex: 1 }}/>
          <span>11 results in 8 ms</span>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, {
  ANewModal, ASearchPalette, IconType,
  ANewTodoBody, ANewEventBody, ANewProjectBody,
  Field, Chip, ChipToggle,
});
