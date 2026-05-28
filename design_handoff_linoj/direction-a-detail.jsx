// ===============================================================
// Direction A — Personal / Company / Calendar — v3
// ===============================================================

// ── PERSONAL: only todos + completed storage box ──
function APersonalView({ mode = 'light' }) {
  const t = A_TOKENS[mode];
  const d = window.LinoJData;
  const [doneSet, setDoneSet] = React.useState(new Set(
    d.personalTodos.filter(x => x.done).map(x => x.id)
  ));
  const toggle = (id) => setDoneSet(s => {
    const n = new Set(s); n.has(id) ? n.delete(id) : n.add(id); return n;
  });

  const allOpen = d.personalTodos.filter(x => !doneSet.has(x.id));
  const allDone = d.personalTodos.filter(x => doneSet.has(x.id));
  const urgent = allOpen.filter(x => x.urgency === 'urgent');
  const normal = allOpen.filter(x => x.urgency === 'normal');

  return (
    <div style={{
      width: '100%', height: '100%', overflow: 'auto',
      background: t.bg, color: t.ink,
      padding: '24px 32px 32px',
    }}>
      <div style={{
        display: 'flex', alignItems: 'flex-end', gap: 16, marginBottom: 22,
      }}>
        <div>
          <div style={{
            fontFamily: A_DISPLAY, fontSize: 28, fontWeight: 600,
            letterSpacing: '-0.025em', lineHeight: 1.05,
          }}>Personal</div>
          <div style={{
            fontSize: 13, color: t.inkSoft, marginTop: 6, fontWeight: 500,
          }}>
            Things only you can do for you ·{' '}
            <b style={{ color: t.ink, fontWeight: 600 }}>{allOpen.length}</b> open
            <span style={{ color: t.inkDim, margin: '0 8px' }}>·</span>
            <b style={{ color: t.ink, fontWeight: 600 }}>{allDone.length}</b> done
          </div>
        </div>
      </div>

      <div style={{
        display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 18,
        maxWidth: 1100, marginBottom: 28,
      }}>
        <ABubbleColumn label="Urgent" tier="urgent"
          count={urgent.length}
          items={urgent} doneSet={doneSet} toggle={toggle} mode={mode}/>
        <ABubbleColumn label="Normal" tier="normal"
          count={normal.length}
          items={normal} doneSet={doneSet} toggle={toggle} mode={mode}/>
      </div>

      {/* Completed storage box */}
      <ACompletedBox
        items={allDone}
        toggle={toggle}
        mode={mode}
      />
    </div>
  );
}

// ── Completed storage box ──
function ACompletedBox({ items, toggle, mode }) {
  const t = A_TOKENS[mode];
  const [open, setOpen] = React.useState(true);
  return (
    <div style={{
      maxWidth: 1100,
      background: t.bgSoft,
      borderRadius: 12,
      border: `0.5px dashed ${t.borderStrong}`,
      padding: '14px 18px 16px',
    }}>
      <div style={{
        display: 'flex', alignItems: 'center', gap: 10,
        cursor: 'pointer',
      }} onClick={() => setOpen(!open)}>
        <svg width="12" height="12" viewBox="0 0 12 12"
          style={{
            transform: open ? 'rotate(90deg)' : 'rotate(0deg)',
            transition: 'transform 0.18s',
            color: t.inkMute,
          }}>
          <path d="M4 2l4 4-4 4" stroke="currentColor" strokeWidth="1.4"
            fill="none" strokeLinecap="round" strokeLinejoin="round"/>
        </svg>
        <div style={{
          fontFamily: A_DISPLAY, fontSize: 14, fontWeight: 600,
          color: t.inkSoft, letterSpacing: '-0.005em',
        }}>Completed</div>
        <div style={{
          fontFamily: A_MONO, fontSize: 11, color: t.inkMute, fontWeight: 600,
          padding: '1px 7px', borderRadius: 4, background: t.chip,
        }}>{items.length}</div>
        <div style={{ flex: 1 }}/>
        <button style={{
          background: 'transparent', border: 'none', cursor: 'pointer',
          color: t.inkMute, fontSize: 11, fontWeight: 500,
          fontFamily: A_FONT, padding: 0,
        }}>Clear all</button>
      </div>
      {open && (
        <div style={{
          marginTop: 10, paddingLeft: 22,
          display: 'flex', flexDirection: 'column', gap: 6,
        }}>
          {items.length === 0 && (
            <div style={{
              fontSize: 12, color: t.inkDim, fontStyle: 'italic', fontWeight: 500,
              padding: '8px 0',
            }}>Nothing finished yet. Empty until you cross something off.</div>
          )}
          {items.map(item => (
            <div key={item.id} style={{
              display: 'flex', alignItems: 'flex-start', gap: 10,
              padding: '5px 0', cursor: 'pointer',
            }} onClick={() => toggle(item.id)}>
              <div style={{ paddingTop: 2 }}>
                <ACheckbox done={true} mode={mode} size={13}/>
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{
                  fontSize: 12.5, fontWeight: 500, color: t.inkMute,
                  letterSpacing: '-0.005em', lineHeight: 1.3,
                  textDecoration: 'line-through',
                  textDecorationColor: t.inkDim,
                }}>{item.title}</div>
              </div>
              <div style={{
                fontSize: 10.5, color: t.inkDim, fontWeight: 500,
                fontStyle: 'italic',
              }}>done</div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

// ── COMPANY: todos + projects ──
function ACompanyView({ mode = 'light' }) {
  const t = A_TOKENS[mode];
  const d = window.LinoJData;
  const [doneSet, setDoneSet] = React.useState(new Set(
    d.workTodos.filter(x => x.done).map(x => x.id)
  ));
  const toggle = (id) => setDoneSet(s => {
    const n = new Set(s); n.has(id) ? n.delete(id) : n.add(id); return n;
  });

  const [scope, setScope] = React.useState('all');

  let items = d.workTodos;
  if (scope === 'loose') items = items.filter(x => !x.project);
  else if (scope !== 'all') items = items.filter(x => x.project === scope);

  const urgent = items.filter(x => x.urgency === 'urgent');
  const normal = items.filter(x => x.urgency === 'normal');

  return (
    <div style={{
      width: '100%', height: '100%', overflow: 'auto',
      background: t.bg, color: t.ink,
      padding: '24px 32px 32px',
    }}>
      <div style={{
        display: 'flex', alignItems: 'flex-end', gap: 16, marginBottom: 18,
      }}>
        <div>
          <div style={{
            fontFamily: A_DISPLAY, fontSize: 28, fontWeight: 600,
            letterSpacing: '-0.025em', lineHeight: 1.05,
          }}>Company</div>
          <div style={{
            fontSize: 13, color: t.inkSoft, marginTop: 6, fontWeight: 500,
          }}>
            <b style={{ color: t.ink, fontWeight: 600 }}>
              {d.workTodos.filter(x => !doneSet.has(x.id)).length}
            </b> todos
            <span style={{ color: t.inkDim, margin: '0 8px' }}>·</span>
            <b style={{ color: t.ink, fontWeight: 600 }}>{d.projects.length}</b> active projects
          </div>
        </div>
        <div style={{ flex: 1 }}/>
        <button style={{
          background: 'transparent', color: t.inkSoft,
          border: `0.5px solid ${t.borderStrong}`,
          cursor: 'pointer', padding: '6px 12px', borderRadius: 7,
          fontSize: 12, fontWeight: 500, fontFamily: A_FONT,
        }}>+ New project</button>
      </div>

      <div style={{ display: 'flex', gap: 6, marginBottom: 18, flexWrap: 'wrap' }}>
        {[
          { key: 'all', label: 'All work' },
          { key: 'loose', label: 'Standalone' },
          ...d.projects.map(p => ({ key: p.id, label: p.title })),
        ].map(f => (
          <button key={f.key} onClick={() => setScope(f.key)} style={{
            padding: '4px 11px', borderRadius: 999,
            border: `0.5px solid ${scope === f.key ? t.borderStrong : t.border}`,
            background: scope === f.key ? t.chip : 'transparent',
            color: scope === f.key ? t.ink : t.inkSoft,
            fontSize: 11.5, fontWeight: scope === f.key ? 600 : 500,
            fontFamily: A_FONT, cursor: 'pointer',
            whiteSpace: 'nowrap',
          }}>{f.label}</button>
        ))}
      </div>

      {/* Todo bubbles */}
      <div style={{
        display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 18,
        marginBottom: 32,
      }}>
        <ABubbleColumn label="Urgent" tier="urgent"
          count={urgent.filter(x => !doneSet.has(x.id)).length}
          items={urgent} doneSet={doneSet} toggle={toggle} mode={mode}/>
        <ABubbleColumn label="Normal" tier="normal"
          count={normal.filter(x => !doneSet.has(x.id)).length}
          items={normal} doneSet={doneSet} toggle={toggle} mode={mode}/>
      </div>

      {/* Projects section */}
      <div style={{
        borderTop: `0.5px solid ${t.rule}`, paddingTop: 20,
        display: 'flex', alignItems: 'baseline', gap: 10, marginBottom: 16,
      }}>
        <div style={{
          fontFamily: A_DISPLAY, fontSize: 20, fontWeight: 600,
          letterSpacing: '-0.02em',
        }}>Projects</div>
        <div style={{ fontSize: 12, color: t.inkMute, fontWeight: 500 }}>
          all your buckets of work
        </div>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
        {d.projects.map(p => (
          <AProjectFullCard key={p.id} project={p} mode={mode}/>
        ))}
      </div>
    </div>
  );
}

function AProjectFullCard({ project, mode }) {
  const t = A_TOKENS[mode];
  const d = window.LinoJData;
  const todos = d.workTodos.filter(w => w.project === project.id);
  const events = d.events.filter(e => e.project === project.id);
  const urgentCount = todos.filter(td => td.urgency === 'urgent' && !td.done).length;

  return (
    <div style={{
      background: t.panel, borderRadius: 12,
      border: `0.5px solid ${t.border}`,
      padding: '18px 22px',
      display: 'grid', gridTemplateColumns: '1.4fr 1fr 1fr', gap: 28,
      cursor: 'pointer',
    }}>
      {/* Left: title + intro + tag + members */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 12, minWidth: 0 }}>
        <div>
          <div style={{
            display: 'flex', alignItems: 'baseline', gap: 10, marginBottom: 6,
          }}>
            <div style={{
              fontFamily: A_DISPLAY, fontSize: 17, fontWeight: 600,
              letterSpacing: '-0.015em', color: t.ink, lineHeight: 1.2,
            }}>{project.title}</div>
            <span style={{
              fontSize: 10.5, fontWeight: 600, color: t.inkSoft,
              padding: '2px 7px', borderRadius: 5,
              background: t.chip,
              textTransform: 'uppercase', letterSpacing: '0.05em',
            }}>{project.tag}</span>
          </div>
          <div style={{
            fontSize: 12.5, color: t.inkSoft, lineHeight: 1.5,
          }}>{project.intro}</div>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 'auto' }}>
          <div style={{ display: 'flex' }}>
            {project.members.map((m, i) => (
              <div key={i} style={{
                marginLeft: i === 0 ? 0 : -6,
                borderRadius: '50%', border: `1.5px solid ${t.panel}`,
              }}>
                <AAvatar name={m} size={22} mode={mode}/>
              </div>
            ))}
          </div>
          <div style={{ fontSize: 11.5, color: t.inkMute, fontWeight: 500 }}>
            {project.members.length} member{project.members.length > 1 ? 's' : ''}
          </div>
        </div>
      </div>

      {/* Middle: todos */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8, minWidth: 0 }}>
        <div style={{
          display: 'flex', alignItems: 'baseline', gap: 6,
        }}>
          <div style={{
            fontSize: 11, fontWeight: 600, color: t.inkMute,
            textTransform: 'uppercase', letterSpacing: '0.06em',
          }}>Todos</div>
          <div style={{
            fontFamily: A_MONO, fontSize: 13, fontWeight: 600,
            color: t.ink, letterSpacing: '-0.02em',
          }}>{todos.filter(td => !td.done).length}</div>
          {urgentCount > 0 && (
            <div style={{
              fontSize: 10.5, fontWeight: 600, color: t.blue,
              padding: '1px 7px', borderRadius: 4,
              background: t.blueSoft,
            }}>{urgentCount} urgent</div>
          )}
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 7 }}>
          {todos.slice(0, 4).map(td => (
            <div key={td.id} style={{
              display: 'flex', alignItems: 'flex-start', gap: 8,
              opacity: td.done ? 0.4 : 1,
            }}>
              <div style={{ paddingTop: 2 }}>
                <ACheckbox done={td.done} mode={mode} size={12}
                  accent={td.urgency === 'urgent' ? 'blue' : 'ink'}/>
              </div>
              <div style={{
                fontSize: 12.5,
                fontWeight: td.urgency === 'urgent' ? 600 : 500,
                color: t.ink, lineHeight: 1.35,
                textDecoration: td.done ? 'line-through' : 'none',
              }}>{td.title}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Right: linked events */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8, minWidth: 0 }}>
        <div style={{
          display: 'flex', alignItems: 'baseline', gap: 6,
        }}>
          <div style={{
            fontSize: 11, fontWeight: 600, color: t.inkMute,
            textTransform: 'uppercase', letterSpacing: '0.06em',
          }}>Linked events</div>
          <div style={{
            fontFamily: A_MONO, fontSize: 13, fontWeight: 600,
            color: t.ink, letterSpacing: '-0.02em',
          }}>{events.length}</div>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 7 }}>
          {events.map(e => {
            const dayLabel = window.LinoJData.weekDays.find(w => w.key === e.day)?.label || e.day;
            return (
              <div key={e.id} style={{
                display: 'flex', gap: 10, alignItems: 'baseline',
              }}>
                <div style={{
                  fontSize: 10.5, color: t.inkMute, fontFamily: A_MONO,
                  fontWeight: 500, width: 64, flexShrink: 0,
                }}>{dayLabel} · {window.AFmtTime(e.start)}</div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{
                    fontSize: 12, fontWeight: 500, color: t.ink, lineHeight: 1.3,
                    letterSpacing: '-0.005em',
                  }}>{e.title}</div>
                  <div style={{ fontSize: 10.5, color: t.inkMute, marginTop: 2 }}>
                    {e.where}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

// ── CALENDAR: rolling next 7 days ──
function ACalendarView({ mode = 'light' }) {
  const t = A_TOKENS[mode];
  const d = window.LinoJData;
  const startHour = 7, endHour = 21;
  const hours = endHour - startHour;
  const pxPerHour = 46;
  const totalH = hours * pxPerHour;
  const nowHour = 11.3;
  const nowTop = (nowHour - startHour) * pxPerHour;

  return (
    <div style={{
      width: '100%', height: '100%', overflow: 'hidden',
      background: t.bg, color: t.ink,
      display: 'flex', flexDirection: 'column',
      padding: '22px 28px 0',
    }}>
      <div style={{
        display: 'flex', alignItems: 'flex-end', gap: 12, marginBottom: 16,
        flexWrap: 'wrap',
      }}>
        <div>
          <div style={{
            fontFamily: A_DISPLAY, fontSize: 26, fontWeight: 600,
            letterSpacing: '-0.025em', lineHeight: 1.05,
          }}>Calendar</div>
          <div style={{
            fontSize: 12.5, color: t.inkSoft, marginTop: 6, fontWeight: 500,
          }}>
            <b style={{ color: t.ink, fontWeight: 600 }}>{d.events.length}</b> events · next 7 days
          </div>
        </div>
        <div style={{ flex: 1 }}/>
        <div style={{
          display: 'flex', alignItems: 'center', gap: 6,
          fontSize: 12, fontFamily: A_FONT, color: t.inkSoft, fontWeight: 500,
        }}>
          <button style={btnIcon(t)}>‹</button>
          <span style={{
            minWidth: 104, textAlign: 'center', color: t.ink, fontWeight: 600,
            fontSize: 12.5,
          }}>
            May 27 — Jun 2
          </span>
          <button style={btnIcon(t)}>›</button>
          <button style={{
            ...btnIcon(t), width: 'auto', padding: '0 10px',
            fontSize: 11.5, fontWeight: 600,
          }}>Today</button>
        </div>
        <button style={{
          background: t.ink, color: t.bg, border: 'none', cursor: 'pointer',
          padding: '6px 12px', borderRadius: 7,
          fontSize: 12.5, fontWeight: 600, fontFamily: A_FONT,
          whiteSpace: 'nowrap',
        }}>+ New event</button>
      </div>

      <div style={{
        display: 'grid', gridTemplateColumns: '52px repeat(7, 1fr)',
        borderBottom: `0.5px solid ${t.border}`,
        paddingBottom: 10, marginBottom: 4, flexShrink: 0,
      }}>
        <div/>
        {d.weekDays.map(day => (
          <div key={day.key} style={{
            display: 'flex', flexDirection: 'column',
            alignItems: 'flex-start', paddingLeft: 8,
          }}>
            <div style={{
              fontSize: 10.5, fontWeight: 600, color: t.inkMute,
              textTransform: 'uppercase', letterSpacing: '0.06em',
              opacity: day.weekend ? 0.7 : 1,
            }}>{day.label}</div>
            <div style={{
              fontFamily: A_DISPLAY, fontSize: 20, fontWeight: 600,
              letterSpacing: '-0.02em', marginTop: 2,
              color: day.today ? t.ink : day.weekend ? t.inkSoft : t.ink,
              display: 'flex', alignItems: 'center', gap: 6,
            }}>
              <span>{day.date}</span>
              {day.today && (
                <span style={{
                  display: 'inline-block', width: 5, height: 5, borderRadius: '50%',
                  background: t.ink,
                }}/>
              )}
            </div>
          </div>
        ))}
      </div>

      <div style={{ flex: 1, overflow: 'auto', position: 'relative' }}>
        <div style={{
          display: 'grid', gridTemplateColumns: '52px repeat(7, 1fr)',
          position: 'relative', height: totalH,
        }}>
          <div style={{ position: 'relative' }}>
            {Array.from({ length: hours + 1 }).map((_, i) => {
              const h = startHour + i;
              const top = i * pxPerHour;
              const labelHour = h > 12 ? h - 12 : h;
              const ampm = h >= 12 ? 'PM' : 'AM';
              return (
                <div key={i} style={{
                  position: 'absolute', left: 0, top: top - 6,
                  fontSize: 10, color: t.inkMute, fontWeight: 500,
                  fontFamily: A_MONO, letterSpacing: '-0.02em',
                }}>{labelHour} {ampm}</div>
              );
            })}
          </div>
          {d.weekDays.map((day) => {
            const dayEvents = d.events.filter(e => e.day === day.key);
            return (
              <div key={day.key} style={{
                position: 'relative',
                borderLeft: `0.5px solid ${t.border}`,
              }}>
                {Array.from({ length: hours + 1 }).map((_, i) => (
                  <div key={i} style={{
                    position: 'absolute', left: 0, right: 0,
                    top: i * pxPerHour, height: 0.5,
                    background: t.border,
                  }}/>
                ))}
                {day.today && (
                  <div style={{
                    position: 'absolute', inset: 0,
                    background: mode === 'light' ? 'rgba(0,0,0,0.025)' : 'rgba(255,255,255,0.025)',
                  }}/>
                )}
                {day.today && (
                  <div style={{
                    position: 'absolute', left: 0, right: 0, top: nowTop,
                    height: 1, background: t.ink, zIndex: 3,
                  }}>
                    <div style={{
                      position: 'absolute', left: -3, top: -3,
                      width: 7, height: 7, borderRadius: '50%', background: t.ink,
                    }}/>
                  </div>
                )}
                {dayEvents.map(e => {
                  const top = (e.start - startHour) * pxPerHour + 2;
                  const h = (e.end - e.start) * pxPerHour - 4;
                  return (
                    <div key={e.id} style={{
                      position: 'absolute', left: 4, right: 4, top, height: h,
                      padding: '6px 8px',
                      background: mode === 'light' ? '#fff' : '#1c1c1d',
                      border: `0.5px solid ${t.borderStrong}`,
                      borderLeft: `2px solid ${t.ink}`,
                      borderRadius: 5,
                      display: 'flex', flexDirection: 'column', gap: 1,
                      overflow: 'hidden', cursor: 'pointer', zIndex: 2,
                    }}>
                      <div style={{
                        fontSize: 11, fontWeight: 600, color: t.ink,
                        letterSpacing: '-0.005em', lineHeight: 1.2,
                        whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
                      }}>{e.title}</div>
                      <div style={{
                        fontSize: 9.5, color: t.inkSoft, fontWeight: 500,
                        whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
                      }}>
                        {window.AFmtTime(e.start)} {e.where && `· ${e.where}`}
                      </div>
                      {h > 50 && e.who.length > 0 && (
                        <div style={{ display: 'flex', marginTop: 'auto', paddingTop: 4 }}>
                          {e.who.slice(0, 3).map((m, i) => (
                            <div key={i} style={{
                              marginLeft: i === 0 ? 0 : -4,
                              borderRadius: '50%',
                              border: `1px solid ${mode === 'light' ? '#fff' : '#1c1c1d'}`,
                            }}>
                              <AAvatar name={m} size={14} mode={mode}/>
                            </div>
                          ))}
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

function btnIcon(t) {
  return {
    width: 26, height: 26, borderRadius: 6,
    background: 'transparent', border: `0.5px solid ${t.border}`,
    color: t.inkSoft, fontSize: 14, lineHeight: 1, fontWeight: 500,
    cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center',
  };
}

Object.assign(window, {
  APersonalView, ACompanyView, ACalendarView, AProjectFullCard,
  ACompletedBox,
});
