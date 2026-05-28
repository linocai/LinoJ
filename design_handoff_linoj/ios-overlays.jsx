// ===============================================================
// iOS overlays — New (bottom sheet) & Search (full-screen modal)
// ===============================================================

// ── iOS New sheet (slides up from bottom) ──
function IosNewSheet({ mode = 'light', kind = 'project' }) {
  const t = I_TOKENS[mode];
  const [activeKind, setActiveKind] = React.useState(kind);
  const [urgent, setUrgent] = React.useState(false);

  return (
    <div style={{
      position: 'absolute', inset: 0, zIndex: 100,
      display: 'flex', flexDirection: 'column', justifyContent: 'flex-end',
      background: 'rgba(0,0,0,0.42)',
    }}>
      <div style={{
        background: t.bg, color: t.ink,
        borderTopLeftRadius: 24, borderTopRightRadius: 24,
        paddingBottom: 0,
        boxShadow: '0 -8px 40px rgba(0,0,0,0.20)',
        maxHeight: '92%',
        display: 'flex', flexDirection: 'column',
      }}>
        {/* Grab handle */}
        <div style={{ padding: '8px 0 0', display: 'flex', justifyContent: 'center' }}>
          <div style={{
            width: 36, height: 5, borderRadius: 999,
            background: t.borderStrong,
          }}/>
        </div>

        {/* Header */}
        <div style={{
          display: 'flex', alignItems: 'center',
          padding: '10px 16px 12px',
        }}>
          <button style={{
            background: 'transparent', border: 'none', cursor: 'pointer',
            color: t.inkSoft, fontSize: 16, fontWeight: 500,
            fontFamily: I_FONT, padding: 0,
          }}>Cancel</button>
          <div style={{ flex: 1, textAlign: 'center' }}>
            <div style={{
              fontFamily: I_DISPLAY, fontSize: 16, fontWeight: 600,
              letterSpacing: '-0.01em',
            }}>New</div>
          </div>
          <button style={{
            background: t.ink, color: t.bg, border: 'none', cursor: 'pointer',
            fontSize: 14, fontWeight: 600, fontFamily: I_FONT,
            padding: '6px 14px', borderRadius: 16,
          }}>Create</button>
        </div>

        {/* Tabs */}
        <div style={{ padding: '0 16px 14px' }}>
          <div style={{
            display: 'flex', padding: 3,
            background: t.chip, borderRadius: 10,
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
                    flex: 1,
                    background: isActive ? t.panel : 'transparent',
                    color: isActive ? t.ink : t.inkSoft,
                    border: 'none', cursor: 'pointer',
                    padding: '7px 0', borderRadius: 8,
                    fontSize: 13, fontWeight: isActive ? 600 : 500,
                    fontFamily: I_FONT,
                    boxShadow: isActive ? '0 0.5px 2px rgba(0,0,0,0.08)' : 'none',
                    display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
                  }}>
                  <IconType kind={opt.key} size={12} color={isActive ? t.ink : t.inkMute}/>
                  {opt.label}
                </button>
              );
            })}
          </div>
        </div>

        {/* Body */}
        <div style={{ flex: 1, overflow: 'auto', paddingBottom: 30 }}>
          {activeKind === 'todo' && <IosNewTodoBody t={t} urgent={urgent} setUrgent={setUrgent} mode={mode}/>}
          {activeKind === 'event' && <IosNewEventBody t={t} mode={mode}/>}
          {activeKind === 'project' && <IosNewProjectBody t={t} mode={mode}/>}
        </div>
      </div>
    </div>
  );
}

function IosNewTodoBody({ t, urgent, setUrgent, mode }) {
  return (
    <div style={{ padding: '6px 16px 20px', display: 'flex', flexDirection: 'column', gap: 14 }}>
      <input autoFocus defaultValue="Outline Q3 retro doc"
        placeholder="What needs to be done?"
        style={{
          background: t.panel,
          border: `0.5px solid ${t.border}`,
          borderRadius: 12,
          padding: '14px 16px',
          fontFamily: I_DISPLAY, fontSize: 18, fontWeight: 600,
          letterSpacing: '-0.02em', color: t.ink, outline: 'none',
        }}/>

      <IosFieldGroup label="Urgency" t={t}>
        <div style={{ display: 'flex', gap: 8 }}>
          <IosToggleChip label="Urgent" active={urgent} onChange={() => setUrgent(!urgent)} t={t} blue/>
          <IosToggleChip label="Normal" active={!urgent} onChange={() => setUrgent(false)} t={t}/>
        </div>
      </IosFieldGroup>

      <IosFieldGroup label="Scope" t={t}>
        <div style={{ display: 'flex', gap: 8 }}>
          <IosToggleChip label="Personal" active={false} t={t}/>
          <IosToggleChip label="Company" active={true} t={t}/>
        </div>
      </IosFieldGroup>

      <IosFieldGroup label="Project" t={t} optional>
        <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
          <IosToggleChip label="None" t={t}/>
          <IosToggleChip label="LinoJ for macOS v1" active t={t}/>
          <IosToggleChip label="Onboarding redesign" t={t}/>
          <IosToggleChip label="Q3 planning" t={t}/>
        </div>
      </IosFieldGroup>
    </div>
  );
}

function IosNewEventBody({ t, mode }) {
  return (
    <div style={{ padding: '6px 16px 20px', display: 'flex', flexDirection: 'column', gap: 14 }}>
      <input defaultValue="Q3 retro review" placeholder="Event name"
        style={{
          background: t.panel, border: `0.5px solid ${t.border}`,
          borderRadius: 12, padding: '14px 16px',
          fontFamily: I_DISPLAY, fontSize: 18, fontWeight: 600,
          letterSpacing: '-0.02em', color: t.ink, outline: 'none',
        }}/>

      <div style={{
        background: t.panel, border: `0.5px solid ${t.border}`,
        borderRadius: 12, overflow: 'hidden',
      }}>
        <IosListItem t={t} label="Date" value="Fri, May 30"/>
        <IosListItem t={t} label="Starts" value="2:00 PM"/>
        <IosListItem t={t} label="Ends" value="3:00 PM" isLast/>
      </div>

      <div style={{
        background: t.panel, border: `0.5px solid ${t.border}`,
        borderRadius: 12, overflow: 'hidden',
      }}>
        <IosListItem t={t} label="Location" value="Conf Rm A"/>
        <IosListItem t={t} label="Link to project" value="LinoJ for macOS v1" isLast soft/>
      </div>

      <IosFieldGroup label="Attendees" t={t}>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          {['Mei', 'Andy', 'Jia'].map(n => (
            <div key={n} style={{
              display: 'flex', alignItems: 'center', gap: 6,
              padding: '4px 10px 4px 4px',
              background: t.chip, borderRadius: 999,
            }}>
              <AAvatar name={n} size={22} mode={mode}/>
              <span style={{ fontSize: 13, fontWeight: 500 }}>{n}</span>
            </div>
          ))}
          <button style={{
            padding: '4px 12px', borderRadius: 999,
            border: `0.5px dashed ${t.borderStrong}`,
            background: 'transparent', color: t.inkSoft,
            fontSize: 13, fontWeight: 500, cursor: 'pointer',
            fontFamily: I_FONT,
          }}>+ Add</button>
        </div>
      </IosFieldGroup>
    </div>
  );
}

function IosNewProjectBody({ t, mode }) {
  return (
    <div style={{ padding: '6px 16px 20px', display: 'flex', flexDirection: 'column', gap: 14 }}>
      <input defaultValue="Calendar v2" placeholder="Project name"
        style={{
          background: t.panel, border: `0.5px solid ${t.border}`,
          borderRadius: 12, padding: '14px 16px',
          fontFamily: I_DISPLAY, fontSize: 18, fontWeight: 600,
          letterSpacing: '-0.02em', color: t.ink, outline: 'none',
        }}/>
      <textarea
        defaultValue="Rebuild the week timeline to feel like a calm page, not a grid. cmd-K driven nav, tighter event creation."
        style={{
          background: t.panel, border: `0.5px solid ${t.border}`,
          borderRadius: 12, padding: '12px 16px',
          fontFamily: I_FONT, fontSize: 14, fontWeight: 500,
          color: t.inkSoft, lineHeight: 1.5,
          outline: 'none', resize: 'none', minHeight: 80,
        }}/>

      <IosFieldGroup label="Tag" t={t} hint="Free-form status">
        <input defaultValue="Shipping July"
          style={{
            background: t.panel, border: `0.5px solid ${t.border}`,
            borderRadius: 12, padding: '12px 16px',
            fontFamily: I_FONT, fontSize: 14, fontWeight: 500,
            color: t.ink, outline: 'none', width: '100%',
            boxSizing: 'border-box',
          }}/>
      </IosFieldGroup>

      <IosFieldGroup label="Members" t={t}>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          {[{n: 'L', label: 'Linus (you)'}, {n: 'M', label: 'Mei'}].map(({n, label}, i) => (
            <div key={i} style={{
              display: 'flex', alignItems: 'center', gap: 6,
              padding: '4px 10px 4px 4px',
              background: t.chip, borderRadius: 999,
            }}>
              <AAvatar name={n} size={22} mode={mode}/>
              <span style={{ fontSize: 13, fontWeight: 500 }}>{label}</span>
            </div>
          ))}
          <button style={{
            padding: '4px 12px', borderRadius: 999,
            border: `0.5px dashed ${t.borderStrong}`,
            background: 'transparent', color: t.inkSoft,
            fontSize: 13, fontWeight: 500, cursor: 'pointer',
            fontFamily: I_FONT,
          }}>+ Invite</button>
        </div>
      </IosFieldGroup>
    </div>
  );
}

function IosFieldGroup({ label, optional, hint, children, t }) {
  return (
    <div>
      <div style={{
        display: 'flex', alignItems: 'baseline', gap: 6,
        fontSize: 11, fontWeight: 700, color: t.inkMute,
        textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: 8,
        paddingLeft: 4,
      }}>
        <span>{label}</span>
        {optional && <span style={{ fontWeight: 500, opacity: 0.6 }}>· optional</span>}
      </div>
      {children}
      {hint && (
        <div style={{
          fontSize: 11.5, color: t.inkMute, marginTop: 6,
          fontStyle: 'italic', paddingLeft: 4,
        }}>{hint}</div>
      )}
    </div>
  );
}

function IosListItem({ t, label, value, isLast, soft }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      padding: '14px 16px',
      borderBottom: isLast ? 'none' : `0.5px solid ${t.border}`,
      cursor: 'pointer',
    }}>
      <div style={{
        fontSize: 14, fontWeight: 500, color: t.ink,
      }}>{label}</div>
      <div style={{
        display: 'flex', alignItems: 'center', gap: 6,
        fontSize: 14, fontWeight: 500, color: soft ? t.inkMute : t.inkSoft,
      }}>
        <span>{value}</span>
        <svg width="8" height="12" viewBox="0 0 8 12" fill="none" style={{ opacity: 0.4 }}>
          <path d="M2 2l4 4-4 4" stroke="currentColor" strokeWidth="1.4"
            fill="none" strokeLinecap="round" strokeLinejoin="round"/>
        </svg>
      </div>
    </div>
  );
}

function IosToggleChip({ label, active, onChange, t, blue }) {
  return (
    <button onClick={onChange} style={{
      padding: '7px 14px', borderRadius: 999,
      border: `0.5px solid ${
        active
          ? (blue ? t.blueBorder : t.borderStrong)
          : t.border
      }`,
      background: active
        ? (blue ? t.blueSoft : t.chip)
        : t.panel,
      color: active
        ? (blue ? t.blueInk : t.ink)
        : t.inkSoft,
      fontSize: 13, fontWeight: active ? 700 : 500,
      fontFamily: I_FONT, cursor: 'pointer',
      display: 'inline-flex', alignItems: 'center', gap: 6,
      whiteSpace: 'nowrap',
    }}>
      {blue && active && (
        <span style={{
          width: 6, height: 6, borderRadius: '50%', background: t.blue,
        }}/>
      )}
      {label}
    </button>
  );
}

// ── iOS Search screen (full-screen modal) ──
function IosSearchScreen({ mode = 'light' }) {
  const t = I_TOKENS[mode];
  const groups = [
    {
      label: 'Quick actions',
      items: [
        { type: 'cmd', icon: 'todo', title: 'New todo "review draft"' },
        { type: 'cmd', icon: 'project', title: 'New project…' },
      ],
    },
    {
      label: 'Todos',
      items: [
        { type: 'todo', icon: 'todo', title: 'Review legal redlines', hint: 'Company · Standalone' },
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
        { type: 'project', icon: 'project', title: 'LinoJ for macOS v1', hint: '5 todos · 2 events' },
      ],
    },
  ];

  return (
    <div style={{
      position: 'absolute', inset: 0, zIndex: 100,
      background: t.bg, color: t.ink,
      display: 'flex', flexDirection: 'column',
    }}>
      {/* Top bar with search field */}
      <div style={{
        paddingTop: 60, padding: '60px 16px 12px',
        display: 'flex', alignItems: 'center', gap: 10,
      }}>
        <div style={{
          flex: 1, display: 'flex', alignItems: 'center', gap: 10,
          padding: '10px 14px',
          background: t.chip, borderRadius: 12,
        }}>
          <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
            <circle cx="6" cy="6" r="4" stroke={t.inkSoft} strokeWidth="1.4"/>
            <path d="M9 9l3.5 3.5" stroke={t.inkSoft} strokeWidth="1.4" strokeLinecap="round"/>
          </svg>
          <input autoFocus defaultValue="review"
            style={{
              flex: 1, background: 'transparent', border: 'none', outline: 'none',
              fontFamily: I_FONT, fontSize: 15, fontWeight: 500,
              color: t.ink, letterSpacing: '-0.005em',
            }}/>
          <div style={{
            width: 18, height: 18, borderRadius: '50%',
            background: t.inkDim, color: t.bg,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontSize: 11, fontWeight: 700, cursor: 'pointer',
          }}>×</div>
        </div>
        <button style={{
          background: 'transparent', border: 'none', cursor: 'pointer',
          color: t.ink, fontSize: 15, fontWeight: 500,
          fontFamily: I_FONT, padding: 0,
        }}>Cancel</button>
      </div>

      {/* Scope chips */}
      <div style={{
        padding: '4px 16px 14px',
        display: 'flex', gap: 6, overflowX: 'auto',
      }}>
        {['All', 'Todos', 'Events', 'Projects'].map((s, i) => (
          <button key={s} style={{
            padding: '5px 12px', borderRadius: 999,
            border: `0.5px solid ${i === 0 ? t.borderStrong : t.border}`,
            background: i === 0 ? t.chip : 'transparent',
            color: i === 0 ? t.ink : t.inkSoft,
            fontSize: 12.5, fontWeight: i === 0 ? 600 : 500,
            fontFamily: I_FONT, cursor: 'pointer',
            whiteSpace: 'nowrap',
          }}>{s}</button>
        ))}
      </div>

      {/* Results */}
      <div style={{ flex: 1, overflow: 'auto', padding: '0 16px 30px' }}>
        {groups.map((g, gi) => (
          <div key={g.label} style={{ marginBottom: 18 }}>
            <div style={{
              fontSize: 10.5, fontWeight: 700, color: t.inkMute,
              textTransform: 'uppercase', letterSpacing: '0.08em',
              padding: '0 4px 8px',
            }}>{g.label}</div>
            <div style={{
              background: t.panel,
              border: `0.5px solid ${t.border}`,
              borderRadius: 12, overflow: 'hidden',
            }}>
              {g.items.map((item, idx) => {
                const isLast = idx === g.items.length - 1;
                return (
                  <div key={idx} style={{
                    display: 'flex', alignItems: 'center', gap: 12,
                    padding: '12px 14px',
                    borderBottom: isLast ? 'none' : `0.5px solid ${t.border}`,
                    cursor: 'pointer',
                  }}>
                    <div style={{
                      width: 28, height: 28, borderRadius: 7,
                      background: t.chip,
                      display: 'flex', alignItems: 'center', justifyContent: 'center',
                      color: t.inkSoft, flexShrink: 0,
                    }}>
                      <IconType kind={item.icon} size={13}/>
                    </div>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{
                        fontSize: 14, fontWeight: item.urgent ? 600 : 500,
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
                          fontSize: 12, color: t.inkMute, marginTop: 2,
                        }}>{item.hint}</div>
                      )}
                    </div>
                    <svg width="8" height="12" viewBox="0 0 8 12" fill="none">
                      <path d="M2 2l4 4-4 4" stroke={t.inkDim} strokeWidth="1.4"
                        fill="none" strokeLinecap="round" strokeLinejoin="round"/>
                    </svg>
                  </div>
                );
              })}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

Object.assign(window, {
  IosNewSheet, IosSearchScreen,
  IosNewTodoBody, IosNewEventBody, IosNewProjectBody,
  IosFieldGroup, IosListItem, IosToggleChip,
});
