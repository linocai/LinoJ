// ===============================================================
// Project detail view — macOS + iOS
// ===============================================================

// ── macOS Project Detail ──
function AProjectDetailView({ projectId = 'linoj', mode = 'light' }) {
  const t = A_TOKENS[mode];
  const d = window.LinoJData;
  const project = d.projects.find(p => p.id === projectId);
  if (!project) return null;

  const todos = d.workTodos.filter(td => td.project === project.id);
  const events = d.events.filter(e => e.project === project.id);
  const [doneSet, setDoneSet] = React.useState(new Set(
    todos.filter(x => x.done).map(x => x.id)
  ));
  const toggle = (id) => setDoneSet(s => {
    const n = new Set(s); n.has(id) ? n.delete(id) : n.add(id); return n;
  });

  const openTodos = todos.filter(td => !doneSet.has(td.id));
  const urgent = openTodos.filter(td => td.urgency === 'urgent');
  const normal = openTodos.filter(td => td.urgency === 'normal');
  const doneTodos = todos.filter(td => doneSet.has(td.id));

  // Group events by day in our weekDays order
  const eventsByDay = d.weekDays.map(day => ({
    day,
    events: events.filter(e => e.day === day.key).sort((a,b) => a.start - b.start),
  })).filter(g => g.events.length > 0);

  return (
    <div style={{
      width: '100%', height: '100%', overflow: 'auto',
      background: t.bg, color: t.ink,
    }}>
      {/* Breadcrumb / back */}
      <div style={{
        padding: '14px 28px 0',
        display: 'flex', alignItems: 'center', gap: 10,
      }}>
        <button style={{
          display: 'flex', alignItems: 'center', gap: 6,
          background: 'transparent', border: 'none', cursor: 'pointer',
          color: t.inkSoft, fontSize: 12.5, fontWeight: 500,
          fontFamily: A_FONT, padding: 0,
        }}>
          <svg width="11" height="11" viewBox="0 0 11 11" fill="none">
            <path d="M7 2L3 5.5L7 9" stroke="currentColor" strokeWidth="1.4"
              fill="none" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>
          Company
        </button>
        <span style={{ color: t.inkDim, fontSize: 12.5 }}>/</span>
        <span style={{ fontSize: 12.5, color: t.ink, fontWeight: 600 }}>{project.title}</span>
        <div style={{ flex: 1 }}/>
        <button style={iconBtn(t)}>
          <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
            <circle cx="3" cy="7" r="1.2" fill="currentColor"/>
            <circle cx="7" cy="7" r="1.2" fill="currentColor"/>
            <circle cx="11" cy="7" r="1.2" fill="currentColor"/>
          </svg>
        </button>
      </div>

      {/* Hero */}
      <div style={{
        padding: '12px 28px 22px',
        borderBottom: `0.5px solid ${t.border}`,
      }}>
        <div style={{
          display: 'flex', alignItems: 'baseline', gap: 14, marginBottom: 10,
        }}>
          <div style={{
            fontFamily: A_DISPLAY, fontSize: 30, fontWeight: 600,
            letterSpacing: '-0.025em', color: t.ink, lineHeight: 1.05,
          }}>{project.title}</div>
          <span style={{
            fontSize: 11, fontWeight: 600, color: t.inkSoft,
            padding: '3px 8px', borderRadius: 5, background: t.chip,
            textTransform: 'uppercase', letterSpacing: '0.06em',
          }}>{project.tag}</span>
          <div style={{ flex: 1 }}/>
          <button style={{
            background: 'transparent', color: t.inkSoft,
            border: `0.5px solid ${t.borderStrong}`,
            cursor: 'pointer', padding: '6px 12px', borderRadius: 7,
            fontSize: 12, fontWeight: 500, fontFamily: A_FONT,
          }}>Edit project</button>
        </div>
        <div style={{
          fontSize: 14, color: t.inkSoft, lineHeight: 1.5,
          maxWidth: 720, marginBottom: 16,
        }}>{project.intro}</div>

        {/* Meta row: members + stats */}
        <div style={{
          display: 'flex', alignItems: 'center', gap: 24,
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{ display: 'flex' }}>
              {project.members.map((m, i) => (
                <div key={i} style={{
                  marginLeft: i === 0 ? 0 : -6,
                  borderRadius: '50%', border: `1.5px solid ${t.bg}`,
                }}>
                  <AAvatar name={m} size={24} mode={mode}/>
                </div>
              ))}
            </div>
            <div style={{ fontSize: 12, color: t.inkMute, fontWeight: 500 }}>
              {project.members.length} member{project.members.length > 1 ? 's' : ''}
            </div>
          </div>
          <Divider t={t}/>
          <Stat label="Open todos" value={openTodos.length} t={t}/>
          {urgent.length > 0 && <Stat label="Urgent" value={urgent.length} t={t} blue/>}
          <Stat label="Done" value={doneTodos.length} t={t} mute/>
          <Divider t={t}/>
          <Stat label="Linked events" value={events.length} t={t}/>
          <Divider t={t}/>
          <Stat label="Created" value={project.createdAt} t={t} mute small/>
        </div>
      </div>

      {/* Two-column body */}
      <div style={{
        display: 'grid', gridTemplateColumns: '1.3fr 1fr', gap: 0,
      }}>
        {/* LEFT — todos */}
        <div style={{
          padding: '22px 28px 28px',
          borderRight: `0.5px solid ${t.border}`,
        }}>
          <div style={{
            fontFamily: A_DISPLAY, fontSize: 16, fontWeight: 600,
            letterSpacing: '-0.015em', marginBottom: 14,
            display: 'flex', alignItems: 'baseline', gap: 8,
          }}>
            Todos
            <span style={{ fontSize: 12, color: t.inkMute, fontWeight: 500 }}>
              {openTodos.length} open · {doneTodos.length} done
            </span>
            <div style={{ flex: 1 }}/>
            <button style={{
              fontSize: 12, color: t.inkSoft, fontWeight: 500,
              background: 'transparent', border: 'none', cursor: 'pointer',
              fontFamily: A_FONT, padding: 0,
            }}>+ Add</button>
          </div>

          <div style={{
            display: 'flex', flexDirection: 'column', gap: 18,
          }}>
            {urgent.length > 0 && (
              <ABubbleColumn label="Urgent" tier="urgent"
                count={urgent.length} items={urgent}
                doneSet={doneSet} toggle={toggle} mode={mode}/>
            )}
            <ABubbleColumn label="Normal" tier="normal"
              count={normal.length} items={normal}
              doneSet={doneSet} toggle={toggle} mode={mode}/>

            {/* Done collapsible */}
            {doneTodos.length > 0 && (
              <ACompletedBox items={doneTodos} toggle={toggle} mode={mode}/>
            )}
          </div>
        </div>

        {/* RIGHT — events timeline + notes */}
        <div style={{
          padding: '22px 28px 28px',
          display: 'flex', flexDirection: 'column', gap: 22,
        }}>
          <div>
            <div style={{
              fontFamily: A_DISPLAY, fontSize: 16, fontWeight: 600,
              letterSpacing: '-0.015em', marginBottom: 14,
              display: 'flex', alignItems: 'baseline', gap: 8,
            }}>
              Linked events
              <span style={{ fontSize: 12, color: t.inkMute, fontWeight: 500 }}>
                {events.length}
              </span>
              <div style={{ flex: 1 }}/>
              <button style={{
                fontSize: 12, color: t.inkSoft, fontWeight: 500,
                background: 'transparent', border: 'none', cursor: 'pointer',
                fontFamily: A_FONT, padding: 0,
              }}>+ Add</button>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
              {eventsByDay.map(g => (
                <div key={g.day.key}>
                  <div style={{
                    display: 'flex', alignItems: 'baseline', gap: 8,
                    marginBottom: 8,
                  }}>
                    <div style={{
                      fontSize: 11, fontWeight: 700, color: g.day.today ? t.ink : t.inkMute,
                      textTransform: 'uppercase', letterSpacing: '0.08em',
                    }}>
                      {g.day.today ? 'Today' : `${g.day.label}, May ${g.day.date}`}
                    </div>
                    {g.day.today && (
                      <span style={{
                        width: 5, height: 5, borderRadius: '50%', background: t.ink,
                      }}/>
                    )}
                  </div>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                    {g.events.map(e => (
                      <AEventRow key={e.id} event={e} mode={mode}/>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          </div>

          {project.notes && (
            <div style={{ paddingTop: 6, borderTop: `0.5px solid ${t.border}` }}>
              <div style={{
                fontFamily: A_DISPLAY, fontSize: 14, fontWeight: 600,
                letterSpacing: '-0.01em', marginTop: 16, marginBottom: 10,
              }}>Notes</div>
              <div style={{
                fontSize: 13, color: t.inkSoft, lineHeight: 1.55,
                whiteSpace: 'pre-line',
              }}>{project.notes}</div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function Stat({ label, value, t, blue, mute, small }) {
  return (
    <div style={{ display: 'flex', alignItems: 'baseline', gap: 6 }}>
      <span style={{
        fontFamily: A_MONO,
        fontSize: small ? 12 : 16, fontWeight: 700,
        letterSpacing: '-0.02em',
        color: blue ? t.blue : mute ? t.inkSoft : t.ink,
      }}>{value}</span>
      <span style={{
        fontSize: 11, color: t.inkMute, fontWeight: 500,
        letterSpacing: '-0.005em',
      }}>{label}</span>
    </div>
  );
}

function Divider({ t }) {
  return <div style={{ width: 0.5, height: 14, background: t.borderStrong }}/>;
}

function iconBtn(t) {
  return {
    width: 26, height: 26, borderRadius: 6,
    background: 'transparent', border: `0.5px solid ${t.border}`,
    color: t.inkSoft, cursor: 'pointer',
    display: 'flex', alignItems: 'center', justifyContent: 'center',
  };
}

function AEventRow({ event, mode }) {
  const t = A_TOKENS[mode];
  return (
    <div style={{
      display: 'grid', gridTemplateColumns: '64px 1fr auto',
      gap: 12, alignItems: 'center',
      padding: '8px 10px',
      background: t.panel,
      border: `0.5px solid ${t.border}`,
      borderLeft: `2px solid ${t.ink}`,
      borderRadius: 6,
      cursor: 'pointer',
    }}>
      <div style={{
        fontFamily: A_MONO, fontSize: 11.5, color: t.ink,
        fontWeight: 600, letterSpacing: '-0.01em',
      }}>{window.AFmtTime(event.start)}</div>
      <div style={{ minWidth: 0 }}>
        <div style={{
          fontSize: 13, fontWeight: 500, color: t.ink,
          letterSpacing: '-0.005em', lineHeight: 1.3,
        }}>{event.title}</div>
        <div style={{ fontSize: 11, color: t.inkMute, marginTop: 1 }}>
          {event.where}
        </div>
      </div>
      <div style={{ display: 'flex' }}>
        {event.who.slice(0, 3).map((m, i) => (
          <div key={i} style={{
            marginLeft: i === 0 ? 0 : -4,
            borderRadius: '50%', border: `1.5px solid ${t.panel}`,
          }}>
            <AAvatar name={m} size={18} mode={mode}/>
          </div>
        ))}
      </div>
    </div>
  );
}

Object.assign(window, {
  AProjectDetailView, AEventRow, Stat, Divider,
});
