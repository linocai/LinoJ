// ===============================================================
// Direction A — "Quiet Workspace" — v3
// Two-tier todos (Urgent / Normal) as bubble cards, blue accent
// on urgent items. New typographic Projects section. Right rail
// gains a "From yesterday" footer for missed events.
// ===============================================================

const A_FONT = '-apple-system, BlinkMacSystemFont, "SF Pro Text", "SF Pro", sans-serif';
const A_DISPLAY = '-apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro", sans-serif';
const A_MONO = 'ui-monospace, "SF Mono", Menlo, monospace';

const A_TOKENS = {
  light: {
    bg: '#fafaf9',
    bgSoft: '#f3f2ef',
    panel: '#ffffff',
    border: 'rgba(15,15,15,0.07)',
    borderStrong: 'rgba(15,15,15,0.12)',
    ink: '#0a0a0a',
    inkSoft: 'rgba(10,10,10,0.62)',
    inkMute: 'rgba(10,10,10,0.42)',
    inkDim: 'rgba(10,10,10,0.22)',
    hover: 'rgba(10,10,10,0.04)',
    chip: 'rgba(10,10,10,0.05)',
    normalBubble: '#ffffff',
    normalBubbleHover: '#fbfaf8',
    blue: '#2563eb',
    blueInk: '#1e40af',
    blueSoft: 'rgba(37,99,235,0.08)',
    blueSofter: 'rgba(37,99,235,0.045)',
    blueBorder: 'rgba(37,99,235,0.22)',
    alertBg: '#0a0a0a',
    alertInk: '#fafaf9',
    rule: 'rgba(15,15,15,0.08)',
  },
  dark: {
    bg: '#0d0d0e',
    bgSoft: '#161617',
    panel: '#181819',
    border: 'rgba(255,255,255,0.07)',
    borderStrong: 'rgba(255,255,255,0.14)',
    ink: '#f6f6f5',
    inkSoft: 'rgba(246,246,245,0.65)',
    inkMute: 'rgba(246,246,245,0.42)',
    inkDim: 'rgba(246,246,245,0.22)',
    hover: 'rgba(255,255,255,0.04)',
    chip: 'rgba(255,255,255,0.06)',
    normalBubble: '#1c1c1d',
    normalBubbleHover: '#222223',
    blue: '#60a5fa',
    blueInk: '#93c5fd',
    blueSoft: 'rgba(96,165,250,0.12)',
    blueSofter: 'rgba(96,165,250,0.06)',
    blueBorder: 'rgba(96,165,250,0.32)',
    alertBg: '#f6f6f5',
    alertInk: '#0d0d0e',
    rule: 'rgba(255,255,255,0.10)',
  },
};

// ── Custom macOS chrome ──
function AWindow({ width = 1440, height = 900, mode = 'light', children, active = 'main', onTab }) {
  const t = A_TOKENS[mode];
  const tabs = [
    { key: 'main', label: 'Main' },
    { key: 'personal', label: 'Personal' },
    { key: 'company', label: 'Company' },
    { key: 'calendar', label: 'Calendar' },
  ];
  return (
    <div style={{
      width, height, borderRadius: 14, overflow: 'hidden',
      background: t.bg, color: t.ink, fontFamily: A_FONT,
      boxShadow: mode === 'light'
        ? '0 0 0 0.5px rgba(0,0,0,0.18), 0 24px 80px rgba(0,0,0,0.18)'
        : '0 0 0 0.5px rgba(255,255,255,0.08), 0 24px 80px rgba(0,0,0,0.6)',
      display: 'flex', flexDirection: 'column',
      position: 'relative',
    }}>
      <div style={{
        height: 44, display: 'flex', alignItems: 'center',
        padding: '0 16px', gap: 16, flexShrink: 0,
        borderBottom: `0.5px solid ${t.border}`,
        background: mode === 'light' ? 'rgba(250,250,249,0.9)' : 'rgba(13,13,14,0.9)',
        backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)',
      }}>
        <ATrafficLights mode={mode} />
        <div style={{
          fontFamily: A_DISPLAY, fontSize: 13, fontWeight: 600,
          letterSpacing: '-0.01em', color: t.ink, paddingLeft: 4,
        }}>
          LinoJ
        </div>
        <div style={{ display: 'flex', gap: 2, marginLeft: 16 }}>
          {tabs.map(tab => {
            const isActive = active === tab.key;
            return (
              <button key={tab.key} onClick={() => onTab?.(tab.key)}
                style={{
                  background: isActive ? t.chip : 'transparent',
                  color: isActive ? t.ink : t.inkSoft,
                  border: 'none', cursor: 'pointer',
                  padding: '5px 11px', borderRadius: 7,
                  fontFamily: A_FONT, fontSize: 12.5,
                  fontWeight: isActive ? 600 : 500,
                  letterSpacing: '-0.005em',
                  transition: 'all 0.15s',
                }}>
                {tab.label}
              </button>
            );
          })}
        </div>
        <div style={{ flex: 1 }} />
        <div style={{
          display: 'flex', alignItems: 'center', gap: 8,
          padding: '5px 10px',
          background: t.chip, borderRadius: 7,
          fontSize: 12, color: t.inkSoft, fontWeight: 500,
          minWidth: 200,
        }}>
          <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
            <circle cx="5" cy="5" r="3.5" stroke="currentColor" strokeWidth="1.3"/>
            <path d="M7.5 7.5L10 10" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round"/>
          </svg>
          <span style={{ flex: 1 }}>Search or jump</span>
          <kbd style={{
            fontFamily: A_MONO, fontSize: 10.5, color: t.inkMute,
            padding: '1px 5px', borderRadius: 3,
            background: mode === 'light' ? 'rgba(0,0,0,0.05)' : 'rgba(255,255,255,0.06)',
          }}>⌘K</kbd>
        </div>
        <button style={{
          background: t.ink, color: t.bg, border: 'none', cursor: 'pointer',
          padding: '5px 12px', borderRadius: 7,
          fontSize: 12.5, fontWeight: 600, fontFamily: A_FONT,
          display: 'flex', alignItems: 'center', gap: 6,
        }}>
          <span style={{ fontSize: 14, lineHeight: 1, marginTop: -1 }}>+</span>
          <span>New</span>
        </button>
      </div>
      <div style={{ flex: 1, overflow: 'hidden', position: 'relative' }}>
        {children}
      </div>
    </div>
  );
}

function ATrafficLights({ mode }) {
  const dot = (bg) => (
    <div style={{
      width: 12, height: 12, borderRadius: '50%', background: bg,
      border: mode === 'dark' ? '0.5px solid rgba(0,0,0,0.3)' : '0.5px solid rgba(0,0,0,0.08)',
    }} />
  );
  return (
    <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
      {dot('#ff5f57')}{dot('#febc2e')}{dot('#28c840')}
    </div>
  );
}

function AAvatar({ name, size = 18, mode = 'light' }) {
  const t = A_TOKENS[mode];
  return (
    <div style={{
      width: size, height: size, borderRadius: '50%',
      background: t.chip, color: t.ink,
      fontSize: size * 0.42, fontWeight: 600,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      letterSpacing: '-0.01em', flexShrink: 0,
      border: `0.5px solid ${t.borderStrong}`,
    }}>
      {name[0]}
    </div>
  );
}

function ACheckbox({ done, onClick, size = 16, mode = 'light', accent = 'ink' }) {
  const t = A_TOKENS[mode];
  const fill = accent === 'blue' ? t.blue : t.ink;
  const border = accent === 'blue' ? t.blueBorder : t.borderStrong;
  return (
    <button onClick={onClick} style={{
      width: size, height: size, borderRadius: size > 14 ? 5 : 4,
      border: `1.4px solid ${done ? fill : border}`,
      background: done ? fill : 'transparent',
      cursor: 'pointer', padding: 0, flexShrink: 0,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      transition: 'all 0.15s',
    }}>
      {done && (
        <svg width={size * 0.65} height={size * 0.65} viewBox="0 0 10 10">
          <path d="M2 5l2 2 4-4" stroke={t.bg} strokeWidth="1.7"
            fill="none" strokeLinecap="round" strokeLinejoin="round"/>
        </svg>
      )}
    </button>
  );
}

// ── Imminent event banner ──
function AEventAlert({ event, minutesUntil, mode }) {
  const t = A_TOKENS[mode];
  if (!event) return null;
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 12,
      padding: '11px 14px',
      background: t.alertBg, color: t.alertInk,
      borderRadius: 11,
      fontSize: 13, fontWeight: 500,
      letterSpacing: '-0.005em',
    }}>
      <div style={{
        width: 7, height: 7, borderRadius: '50%',
        background: mode === 'light' ? '#60a5fa' : '#2563eb',
        animation: 'a-pulse 2s ease-in-out infinite',
        flexShrink: 0,
      }}/>
      <div style={{
        fontFamily: A_MONO, fontSize: 11, fontWeight: 600,
        textTransform: 'uppercase', letterSpacing: '0.08em',
        opacity: 0.65, flexShrink: 0,
      }}>Heads up</div>
      <div style={{ display: 'flex', gap: 8, alignItems: 'baseline' }}>
        <span style={{ fontWeight: 600 }}>{event.title}</span>
        <span style={{ opacity: 0.5 }}>·</span>
        <span style={{ opacity: 0.9 }}>in {minutesUntil} min</span>
        {event.where && (
          <>
            <span style={{ opacity: 0.5 }}>·</span>
            <span style={{ opacity: 0.9 }}>{event.where}</span>
          </>
        )}
      </div>
      <div style={{ flex: 1 }}/>
      <button style={{
        background: 'transparent', border: `0.5px solid ${t.alertInk}`,
        color: t.alertInk, opacity: 0.7,
        padding: '3px 9px', borderRadius: 6,
        fontFamily: A_FONT, fontSize: 11, fontWeight: 600,
        cursor: 'pointer',
      }}>Snooze</button>
      <button style={{
        background: t.alertInk, color: t.alertBg, border: 'none',
        padding: '3px 9px', borderRadius: 6,
        fontFamily: A_FONT, fontSize: 11, fontWeight: 600,
        cursor: 'pointer',
      }}>Open →</button>
    </div>
  );
}

// ===============================================================
// MAIN view
// ===============================================================
function AMainView({ mode = 'light' }) {
  const t = A_TOKENS[mode];
  const d = window.LinoJData;
  const [doneSet, setDoneSet] = React.useState(new Set(
    [...d.personalTodos, ...d.workTodos].filter(x => x.done).map(x => x.id)
  ));
  const toggle = (id) => setDoneSet(s => {
    const n = new Set(s); n.has(id) ? n.delete(id) : n.add(id); return n;
  });

  const NOW = 11.3;
  const todayEvents = d.events.filter(e => e.day === 'Tue');
  const imminent = todayEvents.find(e => e.start > NOW && (e.start - NOW) < 1.5);
  const minutesUntil = imminent ? Math.round((imminent.start - NOW) * 60) : 0;

  const taggedPersonal = d.personalTodos.map(x => ({ ...x, _scope: 'personal' }));
  const taggedWork = d.workTodos.map(x => ({ ...x, _scope: 'work' }));
  const all = [...taggedPersonal, ...taggedWork];

  // Hide completed items from the main panel
  const open = all.filter(x => !doneSet.has(x.id));
  const urgent = open.filter(x => x.urgency === 'urgent');
  const normal = open.filter(x => x.urgency === 'normal');

  return (
    <div style={{
      width: '100%', height: '100%',
      display: 'grid', gridTemplateColumns: '1fr 360px',
      background: t.bg, color: t.ink,
      overflow: 'hidden',
    }}>
      {/* MAIN COLUMN — fixed layout, internal scrolls */}
      <div style={{
        padding: '20px 28px 22px',
        display: 'flex', flexDirection: 'column', gap: 16,
        minHeight: 0, overflow: 'hidden',
      }}>
        {imminent && <AEventAlert event={imminent} minutesUntil={minutesUntil} mode={mode}/>}

        {/* Header */}
        <div style={{
          display: 'flex', alignItems: 'baseline', gap: 16, flexShrink: 0,
        }}>
          <div style={{
            fontFamily: A_DISPLAY, fontSize: 26, fontWeight: 600,
            letterSpacing: '-0.025em', color: t.ink, lineHeight: 1,
          }}>To do</div>
          <div style={{
            fontSize: 13, color: t.inkSoft, fontWeight: 500,
          }}>
            <b style={{ color: t.ink, fontWeight: 600 }}>{open.length}</b> open
            <span style={{ color: t.inkDim, margin: '0 8px' }}>·</span>
            <b style={{ color: t.blue, fontWeight: 600 }}>{urgent.length}</b> urgent
          </div>
        </div>

        {/* Two columns — each scrolls internally */}
        <div style={{
          display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 18,
          flex: 1, minHeight: 0,
        }}>
          <ABubbleColumn label="Urgent" tier="urgent"
            count={urgent.length} items={urgent}
            doneSet={doneSet} toggle={toggle} mode={mode}
            scroll/>
          <ABubbleColumn label="Normal" tier="normal"
            count={normal.length} items={normal}
            doneSet={doneSet} toggle={toggle} mode={mode}
            scroll/>
        </div>

        {/* Projects — pinned at bottom */}
        <AProjectsStrip mode={mode}/>
      </div>

      <AMainRail mode={mode}/>
    </div>
  );
}

// ── Bubble column ──
function ABubbleColumn({ label, tier, count, items, doneSet, toggle, mode, scroll }) {
  const t = A_TOKENS[mode];
  const isUrgent = tier === 'urgent';
  return (
    <div style={{
      display: 'flex', flexDirection: 'column', gap: 10,
      minHeight: 0,
    }}>
      {/* Section header */}
      <div style={{
        display: 'flex', alignItems: 'baseline', gap: 10,
        paddingLeft: 2, flexShrink: 0,
      }}>
        {isUrgent && (
          <div style={{
            width: 8, height: 8, borderRadius: '50%', background: t.blue,
          }}/>
        )}
        <div style={{
          fontFamily: A_DISPLAY, fontSize: 17, fontWeight: 600,
          color: isUrgent ? t.blueInk : t.ink,
          letterSpacing: '-0.015em',
        }}>{label}</div>
        <div style={{
          fontSize: 12, color: t.inkMute, fontWeight: 500,
        }}>{count}</div>
        <div style={{ flex: 1 }}/>
        <button style={{
          background: 'transparent', border: 'none', cursor: 'pointer',
          color: t.inkMute, fontSize: 18, padding: 0, lineHeight: 1,
        }}>+</button>
      </div>
      {/* Bubbles */}
      <div style={{
        display: 'flex', flexDirection: 'column', gap: 8,
        ...(scroll ? {
          overflowY: 'auto', overflowX: 'hidden',
          flex: 1, minHeight: 0,
          paddingRight: 4, marginRight: -4,
        } : {}),
      }}>
        {items.map(item => (
          <ATodoBubble
            key={item.id}
            item={item}
            done={doneSet.has(item.id)}
            onToggle={() => toggle(item.id)}
            urgent={isUrgent}
            mode={mode}
          />
        ))}
        {items.length === 0 && (
          <div style={{
            padding: '20px 0', fontSize: 12.5, color: t.inkDim, fontWeight: 500,
            fontStyle: 'italic', textAlign: 'center',
          }}>Nothing here.</div>
        )}
      </div>
    </div>
  );
}

// ── Todo bubble ──
function ATodoBubble({ item, done, onToggle, urgent, mode }) {
  const t = A_TOKENS[mode];
  const projectTitle = item.project && window.LinoJData.projects.find(p => p.id === item.project)?.title;

  // Visual recipe per tier
  const recipe = urgent ? {
    bg: t.blueSofter,
    border: t.blueBorder,
    leftBar: t.blue,
    titleColor: t.ink,
    titleWeight: 600,
  } : {
    bg: t.normalBubble,
    border: t.border,
    leftBar: null,
    titleColor: t.ink,
    titleWeight: 500,
  };

  return (
    <div
      style={{
        position: 'relative',
        background: recipe.bg,
        border: `0.5px solid ${recipe.border}`,
        borderRadius: 11,
        padding: '12px 14px 12px 16px',
        display: 'flex', alignItems: 'flex-start', gap: 12,
        cursor: 'pointer',
        opacity: done ? 0.45 : 1,
        transition: 'transform 0.12s, background 0.12s',
        overflow: 'hidden',
      }}
      onMouseEnter={e => {
        e.currentTarget.style.transform = 'translateY(-1px)';
        if (!urgent) e.currentTarget.style.background = t.normalBubbleHover;
      }}
      onMouseLeave={e => {
        e.currentTarget.style.transform = 'none';
        if (!urgent) e.currentTarget.style.background = recipe.bg;
      }}
    >
      {recipe.leftBar && (
        <div style={{
          position: 'absolute', left: 0, top: 8, bottom: 8,
          width: 3, background: recipe.leftBar, borderRadius: 2,
        }}/>
      )}
      <div style={{ paddingTop: 1 }}>
        <ACheckbox done={done} onClick={onToggle} mode={mode}
          size={urgent ? 17 : 15}
          accent={urgent ? 'blue' : 'ink'}/>
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{
          fontSize: urgent ? 14.5 : 13.5, fontWeight: recipe.titleWeight,
          color: recipe.titleColor, lineHeight: 1.3,
          letterSpacing: '-0.005em',
          textDecoration: done ? 'line-through' : 'none',
        }}>{item.title}</div>
        {(projectTitle || item._scope) && (
          <div style={{
            display: 'flex', flexWrap: 'wrap', gap: 6, marginTop: 7,
            alignItems: 'center',
          }}>
            {projectTitle && (
              <span style={{
                display: 'inline-flex', alignItems: 'center', gap: 4,
                fontSize: 11, color: t.inkSoft, fontWeight: 500,
                padding: '2px 7px', borderRadius: 5,
                background: t.chip,
              }}>
                <span style={{
                  width: 4, height: 4, borderRadius: '50%', background: t.inkMute,
                }}/>
                {projectTitle}
              </span>
            )}
            {!projectTitle && item._scope && (
              <span style={{
                fontSize: 11, color: t.inkMute, fontWeight: 500,
                fontStyle: 'italic',
              }}>
                {item._scope === 'personal' ? 'Personal' : 'Standalone'}
              </span>
            )}
          </div>
        )}
      </div>
    </div>
  );
}

// ── Projects strip (editorial, pinned bottom on Main) ──
function AProjectsStrip({ mode }) {
  const t = A_TOKENS[mode];
  const d = window.LinoJData;

  return (
    <div style={{
      borderTop: `0.5px solid ${t.rule}`, paddingTop: 14, flexShrink: 0,
    }}>
      <div style={{
        display: 'flex', alignItems: 'baseline', gap: 10, marginBottom: 10,
      }}>
        <div style={{
          fontFamily: A_DISPLAY, fontSize: 16, fontWeight: 600,
          letterSpacing: '-0.015em',
        }}>Projects</div>
        <div style={{ fontSize: 11.5, color: t.inkMute, fontWeight: 500 }}>
          live in Company · {d.projects.length} active
        </div>
        <div style={{ flex: 1 }}/>
        <button style={{
          background: 'transparent', border: 'none', cursor: 'pointer',
          color: t.inkSoft, fontSize: 12, fontWeight: 500,
          fontFamily: A_FONT, padding: 0,
        }}>Open Company →</button>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column' }}>
        {d.projects.map((p, idx) => (
          <AProjectRow key={p.id} project={p} mode={mode}
            isFirst={idx === 0}/>
        ))}
      </div>
    </div>
  );
}

function AProjectRow({ project, mode, isFirst }) {
  const t = A_TOKENS[mode];
  const d = window.LinoJData;
  const todoCount = d.workTodos.filter(td => td.project === project.id && !td.done).length;
  const eventCount = d.events.filter(e => e.project === project.id).length;
  const urgentCount = d.workTodos.filter(td => td.project === project.id && !td.done && td.urgency === 'urgent').length;

  return (
    <div style={{
      display: 'grid',
      gridTemplateColumns: '1fr 200px 110px',
      gap: 24, alignItems: 'center',
      padding: '10px 4px',
      borderTop: isFirst ? 'none' : `0.5px solid ${t.rule}`,
      cursor: 'pointer',
    }}>
      {/* Title + intro + tag */}
      <div style={{ minWidth: 0 }}>
        <div style={{
          display: 'flex', alignItems: 'baseline', gap: 10, marginBottom: 4,
        }}>
          <div style={{
            fontFamily: A_DISPLAY, fontSize: 16, fontWeight: 600,
            letterSpacing: '-0.015em', color: t.ink,
          }}>{project.title}</div>
          <span style={{
            fontSize: 10.5, fontWeight: 600, color: t.inkSoft,
            padding: '2px 7px', borderRadius: 5,
            background: t.chip,
            textTransform: 'uppercase', letterSpacing: '0.05em',
          }}>{project.tag}</span>
        </div>
        <div style={{
          fontSize: 12.5, color: t.inkSoft, lineHeight: 1.4,
          maxWidth: 520,
          overflow: 'hidden', textOverflow: 'ellipsis',
          display: '-webkit-box', WebkitLineClamp: 1, WebkitBoxOrient: 'vertical',
        }}>{project.intro}</div>
      </div>

      {/* Inline stats */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 18,
        fontSize: 13, fontWeight: 500,
      }}>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 5 }}>
          <span style={{
            fontFamily: A_MONO, fontWeight: 600, fontSize: 15,
            letterSpacing: '-0.02em',
            color: urgentCount > 0 ? t.blue : t.ink,
          }}>{todoCount}</span>
          <span style={{ fontSize: 11, color: t.inkSoft }}>
            todo{todoCount !== 1 ? 's' : ''}
            {urgentCount > 0 && <span style={{ color: t.blue }}> · {urgentCount} urgent</span>}
          </span>
        </div>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 5 }}>
          <span style={{
            fontFamily: A_MONO, fontWeight: 600, fontSize: 15,
            letterSpacing: '-0.02em',
            color: t.ink,
          }}>{eventCount}</span>
          <span style={{ fontSize: 11, color: t.inkSoft }}>
            event{eventCount !== 1 ? 's' : ''}
          </span>
        </div>
      </div>

      {/* Members */}
      <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
        {project.members.slice(0, 4).map((m, i) => (
          <div key={i} style={{
            marginLeft: i === 0 ? 0 : -6,
            borderRadius: '50%', border: `1.5px solid ${t.bg}`,
          }}>
            <AAvatar name={m} size={22} mode={mode}/>
          </div>
        ))}
        {project.members.length > 4 && (
          <div style={{
            marginLeft: -6, width: 22, height: 22, borderRadius: '50%',
            background: t.chip, color: t.inkSoft, fontSize: 10,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            border: `1.5px solid ${t.bg}`, fontWeight: 600,
          }}>+{project.members.length - 4}</div>
        )}
      </div>
    </div>
  );
}

// ── Right rail: 7-day look-ahead + yesterday's missed events ──
function AMainRail({ mode }) {
  const t = A_TOKENS[mode];
  const d = window.LinoJData;

  return (
    <div style={{
      borderLeft: `0.5px solid ${t.border}`,
      background: t.bg,
      padding: '20px 18px',
      overflow: 'auto',
      display: 'flex', flexDirection: 'column',
    }}>
      {/* Next 7 days */}
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 10, marginBottom: 8 }}>
        <div style={{
          fontFamily: A_DISPLAY, fontSize: 16, fontWeight: 600,
          letterSpacing: '-0.015em',
        }}>Next 7 days</div>
        <div style={{ flex: 1 }}/>
        <button style={{
          background: 'transparent', border: 'none', cursor: 'pointer',
          color: t.inkSoft, fontSize: 11.5, fontFamily: A_FONT, fontWeight: 500,
          padding: 0,
        }}>Calendar →</button>
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', gap: 0 }}>
        {d.weekDays.map(day => {
          const events = d.events.filter(e => e.day === day.key).sort((a,b) => a.start - b.start);
          return (
            <div key={day.key} style={{
              padding: '10px 0',
              borderTop: `0.5px solid ${t.border}`,
              display: 'grid', gridTemplateColumns: '60px 1fr', gap: 12,
              alignItems: 'baseline',
            }}>
              <div style={{ flexShrink: 0 }}>
                <div style={{
                  fontSize: 10.5, fontWeight: 600,
                  color: day.today ? t.ink : t.inkMute,
                  textTransform: 'uppercase', letterSpacing: '0.06em',
                }}>{day.label}</div>
                <div style={{
                  fontFamily: A_DISPLAY, fontSize: 18, fontWeight: 600,
                  color: day.today ? t.ink : day.weekend ? t.inkSoft : t.ink,
                  letterSpacing: '-0.02em', marginTop: 1,
                  display: 'flex', alignItems: 'center', gap: 5,
                }}>
                  {day.date}
                  {day.today && (
                    <span style={{
                      width: 4, height: 4, borderRadius: '50%', background: t.ink,
                    }}/>
                  )}
                </div>
              </div>
              <div style={{ minWidth: 0, display: 'flex', flexDirection: 'column', gap: 5 }}>
                {events.length === 0 && (
                  <div style={{
                    fontSize: 12, color: t.inkDim, fontWeight: 500,
                    paddingTop: 3, fontStyle: 'italic',
                  }}>Nothing on the books</div>
                )}
                {events.slice(0, 3).map(e => (
                  <div key={e.id} style={{
                    display: 'grid', gridTemplateColumns: '44px 1fr',
                    gap: 8, alignItems: 'baseline',
                  }}>
                    <div style={{
                      fontFamily: A_MONO, fontSize: 10, color: t.inkMute,
                      fontWeight: 500, letterSpacing: '-0.02em',
                      fontVariantNumeric: 'tabular-nums',
                    }}>{fmtTime(e.start)}</div>
                    <div style={{
                      fontSize: 12, color: t.ink, fontWeight: 500,
                      letterSpacing: '-0.005em', lineHeight: 1.3,
                      whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
                    }}>{e.title}</div>
                  </div>
                ))}
                {events.length > 3 && (
                  <div style={{
                    fontSize: 11, color: t.inkMute, paddingLeft: 52, marginTop: 2,
                  }}>+{events.length - 3} more</div>
                )}
              </div>
            </div>
          );
        })}
      </div>

      {/* Yesterday's missed events */}
      <AYesterdayMissed mode={mode}/>
    </div>
  );
}

function AYesterdayMissed({ mode }) {
  const t = A_TOKENS[mode];
  const d = window.LinoJData;
  const [doneSet, setDoneSet] = React.useState(new Set());
  const toggle = (id) => setDoneSet(s => {
    const n = new Set(s); n.has(id) ? n.delete(id) : n.add(id); return n;
  });

  if (!d.yesterdayEvents.length) return null;

  return (
    <div style={{
      marginTop: 22, padding: '14px 14px 12px',
      background: t.chip,
      borderRadius: 10,
      display: 'flex', flexDirection: 'column', gap: 8,
    }}>
      <div style={{
        display: 'flex', alignItems: 'baseline', gap: 8,
      }}>
        <div style={{
          fontSize: 11, fontWeight: 700, color: t.inkMute,
          textTransform: 'uppercase', letterSpacing: '0.08em',
        }}>From yesterday</div>
        <div style={{
          fontSize: 11, color: t.inkDim, fontWeight: 500,
        }}>· May 26</div>
        <div style={{ flex: 1 }}/>
        <div style={{
          fontSize: 10.5, color: t.inkMute, fontStyle: 'italic',
        }}>tap to confirm</div>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
        {d.yesterdayEvents.map(e => {
          const done = doneSet.has(e.id);
          return (
            <div key={e.id} style={{
              display: 'flex', alignItems: 'flex-start', gap: 10,
              padding: '5px 0', cursor: 'pointer',
              opacity: done ? 0.4 : 1,
            }}>
              <div style={{ paddingTop: 1 }}>
                <ACheckbox done={done} onClick={() => toggle(e.id)}
                  mode={mode} size={13}/>
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{
                  fontSize: 12, fontWeight: 500, color: t.inkSoft,
                  letterSpacing: '-0.005em', lineHeight: 1.3,
                  textDecoration: done ? 'line-through' : 'none',
                }}>{e.title}</div>
                <div style={{
                  fontSize: 10.5, color: t.inkMute, marginTop: 2,
                  fontFamily: A_MONO, fontWeight: 500,
                }}>{fmtTime(e.start)} · {e.where}</div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

function fmtTime(h) {
  const hh = Math.floor(h);
  const mm = Math.round((h - hh) * 60);
  const ampm = hh >= 12 ? 'PM' : 'AM';
  const dh = hh > 12 ? hh - 12 : hh === 0 ? 12 : hh;
  return mm === 0 ? `${dh} ${ampm}` : `${dh}:${String(mm).padStart(2, '0')} ${ampm}`;
}

Object.assign(window, {
  AWindow, ATrafficLights, AAvatar, ACheckbox,
  AMainView, AMainRail, ABubbleColumn, ATodoBubble,
  AProjectsStrip, AProjectRow, AYesterdayMissed, AEventAlert,
  A_TOKENS, A_FONT, A_DISPLAY, A_MONO, AFmtTime: fmtTime,
});
