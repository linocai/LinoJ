// ===============================================================
// iOS Project Detail — push view inside Company tab
// ===============================================================

function IosProjectDetailView({ projectId = 'linoj', mode = 'light' }) {
  const t = I_TOKENS[mode];
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

  const eventsByDay = d.weekDays.map(day => ({
    day,
    events: events.filter(e => e.day === day.key).sort((a,b) => a.start - b.start),
  })).filter(g => g.events.length > 0);

  return (
    <div style={{
      position: 'absolute', inset: 0,
      background: t.bg, color: t.ink,
      paddingBottom: 110, overflow: 'auto',
    }}>
      {/* Top bar with back + actions */}
      <div style={{
        position: 'absolute', top: 58, left: 16, right: 16, zIndex: 30,
        display: 'flex', alignItems: 'center', gap: 8,
      }}>
        <Glass radius={20} mode={mode}>
          <button style={{
            padding: '8px 14px 8px 10px',
            background: 'transparent', border: 'none', cursor: 'pointer',
            color: t.ink, display: 'flex', alignItems: 'center', gap: 4,
            fontFamily: I_FONT, fontSize: 14, fontWeight: 500,
            borderRadius: 20,
          }}>
            <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
              <path d="M9 3L5 7L9 11" stroke="currentColor" strokeWidth="1.7"
                fill="none" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
            Company
          </button>
        </Glass>
        <div style={{ flex: 1 }}/>
        <Glass radius={20} mode={mode}>
          <button style={{
            width: 40, height: 40,
            background: 'transparent', border: 'none', cursor: 'pointer',
            color: t.ink, display: 'flex', alignItems: 'center', justifyContent: 'center',
            borderRadius: 20,
          }}>
            <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
              <circle cx="3.5" cy="8" r="1.3" fill="currentColor"/>
              <circle cx="8" cy="8" r="1.3" fill="currentColor"/>
              <circle cx="12.5" cy="8" r="1.3" fill="currentColor"/>
            </svg>
          </button>
        </Glass>
      </div>

      {/* Hero */}
      <div style={{ padding: '112px 20px 18px' }}>
        <span style={{
          display: 'inline-block',
          fontSize: 10, fontWeight: 700, color: t.inkSoft,
          padding: '3px 8px', borderRadius: 5, background: t.chip,
          textTransform: 'uppercase', letterSpacing: '0.08em',
          marginBottom: 10,
        }}>{project.tag}</span>
        <div style={{
          fontFamily: I_DISPLAY, fontSize: 30, fontWeight: 700,
          letterSpacing: '-0.03em', color: t.ink, lineHeight: 1.05,
          marginBottom: 8,
        }}>{project.title}</div>
        <div style={{
          fontSize: 13.5, color: t.inkSoft, lineHeight: 1.5,
        }}>{project.intro}</div>

        {/* Members */}
        <div style={{
          display: 'flex', alignItems: 'center', gap: 10, marginTop: 14,
        }}>
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
            {project.members.length} members · since {project.createdAt}
          </div>
        </div>
      </div>

      {/* Stats card */}
      <div style={{ padding: '0 16px 18px' }}>
        <div style={{
          background: t.panel,
          border: `0.5px solid ${t.border}`,
          borderRadius: 14,
          padding: '14px 16px',
          display: 'flex', alignItems: 'center', gap: 0,
        }}>
          <IosStat label="open" value={openTodos.length} t={t}/>
          {urgent.length > 0 && (
            <>
              <IosStatDivider t={t}/>
              <IosStat label="urgent" value={urgent.length} t={t} blue/>
            </>
          )}
          <IosStatDivider t={t}/>
          <IosStat label="done" value={doneTodos.length} t={t} mute/>
          <IosStatDivider t={t}/>
          <IosStat label="events" value={events.length} t={t}/>
        </div>
      </div>

      {/* Urgent todos */}
      {urgent.length > 0 && (
        <div style={{ padding: '0 16px', display: 'flex', flexDirection: 'column', gap: 8 }}>
          <IosSectionHeader label="Urgent" count={urgent.length} accent mode={mode}/>
          {urgent.map(item => (
            <IosBubble key={item.id} item={item}
              done={doneSet.has(item.id)} onToggle={() => toggle(item.id)}
              urgent mode={mode} compact/>
          ))}
        </div>
      )}

      {/* Normal todos */}
      <div style={{
        padding: '0 16px', marginTop: 18,
        display: 'flex', flexDirection: 'column', gap: 8,
      }}>
        <IosSectionHeader label="Normal" count={normal.length} mode={mode}/>
        <IosCompactList items={normal} doneSet={doneSet} toggle={toggle} mode={mode}/>
      </div>

      {/* Linked events */}
      <div style={{ padding: '24px 16px 0' }}>
        <IosSectionHeader label="Linked events" count={events.length} mode={mode}
          right={
            <button style={{
              fontSize: 12.5, color: t.inkSoft, fontWeight: 500,
              background: 'transparent', border: 'none', padding: 0,
              cursor: 'pointer',
            }}>+ Add</button>
          }/>
        <div style={{ marginTop: 10, display: 'flex', flexDirection: 'column', gap: 14 }}>
          {eventsByDay.map(g => (
            <div key={g.day.key}>
              <div style={{
                display: 'flex', alignItems: 'baseline', gap: 6,
                marginBottom: 8, paddingLeft: 4,
              }}>
                <div style={{
                  fontSize: 11, fontWeight: 700,
                  color: g.day.today ? t.ink : t.inkMute,
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
              <div style={{
                background: t.panel,
                border: `0.5px solid ${t.border}`,
                borderRadius: 12, overflow: 'hidden',
              }}>
                {g.events.map((e, idx) => (
                  <IosEventRow key={e.id} event={e} mode={mode}
                    isLast={idx === g.events.length - 1}/>
                ))}
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Notes */}
      {project.notes && (
        <div style={{ padding: '26px 16px 0' }}>
          <IosSectionHeader label="Notes" mode={mode}/>
          <div style={{
            marginTop: 10,
            background: t.panel,
            border: `0.5px solid ${t.border}`,
            borderRadius: 14, padding: '14px 16px',
            fontSize: 13.5, color: t.inkSoft, lineHeight: 1.55,
            whiteSpace: 'pre-line',
          }}>{project.notes}</div>
        </div>
      )}

      {/* Done collapsible */}
      {doneTodos.length > 0 && (
        <div style={{ padding: '24px 16px 0' }}>
          <IosCompletedBox items={doneTodos} toggle={toggle} mode={mode}/>
        </div>
      )}

      <IosTabBar active="company" mode={mode}/>
    </div>
  );
}

function IosStat({ label, value, t, blue, mute }) {
  return (
    <div style={{
      flex: 1, display: 'flex', flexDirection: 'column',
      alignItems: 'center', gap: 2,
    }}>
      <div style={{
        fontFamily: I_MONO, fontSize: 20, fontWeight: 700,
        letterSpacing: '-0.025em',
        color: blue ? t.blue : mute ? t.inkSoft : t.ink,
      }}>{value}</div>
      <div style={{
        fontSize: 10, fontWeight: 600, color: t.inkMute,
        textTransform: 'uppercase', letterSpacing: '0.08em',
      }}>{label}</div>
    </div>
  );
}

function IosStatDivider({ t }) {
  return <div style={{ width: 0.5, height: 28, background: t.border, alignSelf: 'center' }}/>;
}

function IosEventRow({ event, mode, isLast }) {
  const t = I_TOKENS[mode];
  return (
    <div style={{
      display: 'grid', gridTemplateColumns: '70px 1fr auto',
      gap: 10, alignItems: 'center',
      padding: '12px 14px',
      borderBottom: isLast ? 'none' : `0.5px solid ${t.border}`,
      cursor: 'pointer',
    }}>
      <div style={{
        fontFamily: I_MONO, fontSize: 12, color: t.ink,
        fontWeight: 600, letterSpacing: '-0.01em',
      }}>{window.AFmtTime(event.start)}</div>
      <div style={{ minWidth: 0 }}>
        <div style={{
          fontSize: 13.5, fontWeight: 500, color: t.ink,
          letterSpacing: '-0.005em', lineHeight: 1.3,
        }}>{event.title}</div>
        <div style={{
          fontSize: 11, color: t.inkMute, marginTop: 1,
        }}>{event.where}</div>
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
  IosProjectDetailView, IosStat, IosStatDivider, IosEventRow,
});
