// ===============================================================
// iOS — Personal / Company / Calendar
// ===============================================================

// ── PERSONAL ──
function IosPersonalView({ mode = 'light' }) {
  const t = I_TOKENS[mode];
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
      position: 'absolute', inset: 0,
      background: t.bg, color: t.ink,
      paddingBottom: 110, overflow: 'auto',
    }}>
      <IosTopActions mode={mode}/>

      <div style={{ padding: '64px 20px 14px' }}>
        <div style={{
          fontFamily: I_DISPLAY, fontSize: 34, fontWeight: 700,
          letterSpacing: '-0.03em', color: t.ink, lineHeight: 1,
        }}>Personal</div>
        <div style={{
          fontSize: 13.5, color: t.inkSoft, marginTop: 6, fontWeight: 500,
        }}>
          <b style={{ color: t.ink, fontWeight: 600 }}>{allOpen.length}</b> open
          <span style={{ color: t.inkDim, margin: '0 8px' }}>·</span>
          <b style={{ color: t.ink, fontWeight: 600 }}>{allDone.length}</b> done
        </div>
      </div>

      {/* Urgent */}
      <div style={{ padding: '0 16px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        <IosSectionHeader label="Urgent" count={urgent.length} accent mode={mode}/>
        {urgent.length === 0 && (
          <div style={{
            padding: '14px 0', fontSize: 13, color: t.inkDim,
            fontStyle: 'italic', textAlign: 'center', fontWeight: 500,
          }}>Nothing urgent. Nice.</div>
        )}
        {urgent.map(item => (
          <IosBubble key={item.id} item={item}
            done={doneSet.has(item.id)} onToggle={() => toggle(item.id)}
            urgent mode={mode}/>
        ))}
      </div>

      {/* Normal */}
      <div style={{
        padding: '0 16px', marginTop: 22,
        display: 'flex', flexDirection: 'column', gap: 10,
      }}>
        <IosSectionHeader label="Normal" count={normal.length} mode={mode}/>
        {normal.map(item => (
          <IosBubble key={item.id} item={item}
            done={doneSet.has(item.id)} onToggle={() => toggle(item.id)}
            urgent={false} mode={mode}/>
        ))}
      </div>

      {/* Completed box */}
      <div style={{ padding: '24px 16px 0' }}>
        <IosCompletedBox items={allDone} toggle={toggle} mode={mode}/>
      </div>

      <IosTabBar active="personal" mode={mode}/>
    </div>
  );
}

function IosCompletedBox({ items, toggle, mode }) {
  const t = I_TOKENS[mode];
  const [open, setOpen] = React.useState(true);
  return (
    <div style={{
      background: t.bgSoft,
      border: `0.5px dashed ${t.borderStrong}`,
      borderRadius: 14,
      padding: '14px 14px 14px',
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
          fontFamily: I_DISPLAY, fontSize: 14, fontWeight: 600,
          color: t.inkSoft, letterSpacing: '-0.005em',
        }}>Completed</div>
        <div style={{
          fontFamily: I_MONO, fontSize: 11, color: t.inkMute, fontWeight: 700,
          padding: '1px 7px', borderRadius: 4, background: t.chip,
        }}>{items.length}</div>
        <div style={{ flex: 1 }}/>
        <button style={{
          background: 'transparent', border: 'none', cursor: 'pointer',
          color: t.inkMute, fontSize: 11, fontWeight: 500,
          fontFamily: I_FONT, padding: 0,
        }}>Clear all</button>
      </div>
      {open && (
        <div style={{
          marginTop: 10, paddingLeft: 22,
          display: 'flex', flexDirection: 'column', gap: 6,
        }}>
          {items.length === 0 && (
            <div style={{
              fontSize: 12, color: t.inkDim, fontStyle: 'italic',
              fontWeight: 500, padding: '8px 0',
            }}>Empty until you cross something off.</div>
          )}
          {items.map(item => (
            <div key={item.id} style={{
              display: 'flex', alignItems: 'flex-start', gap: 10,
              padding: '6px 0',
            }} onClick={() => toggle(item.id)}>
              <div style={{ paddingTop: 2 }}>
                <ACheckbox done={true} mode={mode} size={14}/>
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{
                  fontSize: 13, fontWeight: 500, color: t.inkMute,
                  letterSpacing: '-0.005em', lineHeight: 1.3,
                  textDecoration: 'line-through',
                  textDecorationColor: t.inkDim,
                }}>{item.title}</div>
              </div>
              <div style={{
                fontSize: 10.5, color: t.inkDim, fontWeight: 500, fontStyle: 'italic',
              }}>done</div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

// ── COMPANY ──
function IosCompanyView({ mode = 'light' }) {
  const t = I_TOKENS[mode];
  const d = window.LinoJData;
  const [doneSet, setDoneSet] = React.useState(new Set(
    d.workTodos.filter(x => x.done).map(x => x.id)
  ));
  const toggle = (id) => setDoneSet(s => {
    const n = new Set(s); n.has(id) ? n.delete(id) : n.add(id); return n;
  });

  const allOpen = d.workTodos.filter(x => !doneSet.has(x.id));
  const urgent = allOpen.filter(x => x.urgency === 'urgent');
  const normal = allOpen.filter(x => x.urgency === 'normal');

  return (
    <div style={{
      position: 'absolute', inset: 0,
      background: t.bg, color: t.ink,
      paddingBottom: 110, overflow: 'auto',
    }}>
      <IosTopActions mode={mode}/>

      <div style={{ padding: '64px 20px 14px' }}>
        <div style={{
          fontFamily: I_DISPLAY, fontSize: 34, fontWeight: 700,
          letterSpacing: '-0.03em', color: t.ink, lineHeight: 1,
        }}>Company</div>
        <div style={{
          fontSize: 13.5, color: t.inkSoft, marginTop: 6, fontWeight: 500,
        }}>
          <b style={{ color: t.ink, fontWeight: 600 }}>{allOpen.length}</b> todos
          <span style={{ color: t.inkDim, margin: '0 8px' }}>·</span>
          <b style={{ color: t.ink, fontWeight: 600 }}>{d.projects.length}</b> projects
        </div>
      </div>

      {/* Urgent */}
      <div style={{ padding: '0 16px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        <IosSectionHeader label="Urgent" count={urgent.length} accent mode={mode}/>
        {urgent.map(item => (
          <IosBubble key={item.id} item={item}
            done={doneSet.has(item.id)} onToggle={() => toggle(item.id)}
            urgent mode={mode}/>
        ))}
      </div>

      {/* Normal */}
      <div style={{
        padding: '0 16px', marginTop: 22,
        display: 'flex', flexDirection: 'column', gap: 10,
      }}>
        <IosSectionHeader label="Normal" count={normal.length} mode={mode}/>
        {normal.map(item => (
          <IosBubble key={item.id} item={item}
            done={doneSet.has(item.id)} onToggle={() => toggle(item.id)}
            urgent={false} mode={mode}/>
        ))}
      </div>

      {/* Projects — full cards */}
      <div style={{ padding: '26px 16px 0' }}>
        <IosSectionHeader label="Projects" count={d.projects.length} mode={mode}
          right={
            <button style={{
              fontSize: 12.5, color: t.inkSoft, fontWeight: 500,
              background: 'transparent', border: 'none', padding: 0,
              cursor: 'pointer',
            }}>+ New</button>
          }/>
        <div style={{
          marginTop: 12, display: 'flex', flexDirection: 'column', gap: 10,
        }}>
          {d.projects.map(p => <IosProjectDetailCard key={p.id} project={p} mode={mode}/>)}
        </div>
      </div>

      <IosTabBar active="company" mode={mode}/>
    </div>
  );
}

// Detailed project card for Company tab
function IosProjectDetailCard({ project, mode }) {
  const t = I_TOKENS[mode];
  const d = window.LinoJData;
  const todos = d.workTodos.filter(td => td.project === project.id);
  const events = d.events.filter(e => e.project === project.id);
  const urgentCount = todos.filter(td => td.urgency === 'urgent' && !td.done).length;
  const openTodos = todos.filter(td => !td.done).length;

  return (
    <div style={{
      background: t.panel,
      border: `0.5px solid ${t.border}`,
      borderRadius: 14,
      padding: '14px 16px',
      display: 'flex', flexDirection: 'column', gap: 12,
    }}>
      {/* Header */}
      <div style={{
        display: 'flex', alignItems: 'baseline', gap: 8, flexWrap: 'wrap',
      }}>
        <div style={{
          fontFamily: I_DISPLAY, fontSize: 16, fontWeight: 600,
          letterSpacing: '-0.015em', color: t.ink,
        }}>{project.title}</div>
        <span style={{
          fontSize: 9.5, fontWeight: 600, color: t.inkSoft,
          padding: '2px 6px', borderRadius: 4, background: t.chip,
          textTransform: 'uppercase', letterSpacing: '0.05em',
        }}>{project.tag}</span>
      </div>
      <div style={{
        fontSize: 12.5, color: t.inkSoft, lineHeight: 1.45,
      }}>{project.intro}</div>

      {/* Stats row */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 14,
        paddingTop: 4,
      }}>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 5 }}>
          <span style={{
            fontFamily: I_MONO, fontWeight: 700, fontSize: 16,
            letterSpacing: '-0.02em',
            color: urgentCount > 0 ? t.blue : t.ink,
          }}>{openTodos}</span>
          <span style={{ fontSize: 11.5, color: t.inkSoft, fontWeight: 500 }}>
            todos{urgentCount > 0 && <span style={{ color: t.blue, fontWeight: 600 }}> · {urgentCount} urgent</span>}
          </span>
        </div>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 5 }}>
          <span style={{
            fontFamily: I_MONO, fontWeight: 700, fontSize: 16,
            letterSpacing: '-0.02em', color: t.ink,
          }}>{events.length}</span>
          <span style={{ fontSize: 11.5, color: t.inkSoft, fontWeight: 500 }}>events</span>
        </div>
        <div style={{ flex: 1 }}/>
        <div style={{ display: 'flex' }}>
          {project.members.slice(0, 3).map((m, i) => (
            <div key={i} style={{
              marginLeft: i === 0 ? 0 : -5,
              borderRadius: '50%', border: `1.5px solid ${t.panel}`,
            }}>
              <AAvatar name={m} size={20} mode={mode}/>
            </div>
          ))}
        </div>
      </div>

      {/* Mini events */}
      {events.length > 0 && (
        <div style={{
          paddingTop: 10, borderTop: `0.5px solid ${t.border}`,
          display: 'flex', flexDirection: 'column', gap: 6,
        }}>
          <div style={{
            fontSize: 10, fontWeight: 700, color: t.inkMute,
            textTransform: 'uppercase', letterSpacing: '0.08em',
          }}>Linked events</div>
          {events.slice(0, 2).map(e => {
            const dayLabel = window.LinoJData.weekDays.find(w => w.key === e.day)?.label || e.day;
            return (
              <div key={e.id} style={{
                display: 'flex', alignItems: 'baseline', gap: 10,
              }}>
                <div style={{
                  fontSize: 10.5, color: t.inkMute, fontFamily: I_MONO,
                  fontWeight: 500, width: 56, flexShrink: 0,
                }}>{dayLabel} · {window.AFmtTime(e.start)}</div>
                <div style={{
                  fontSize: 12.5, fontWeight: 500, color: t.ink,
                  flex: 1, minWidth: 0,
                  whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
                }}>{e.title}</div>
              </div>
            );
          })}
          {events.length > 2 && (
            <div style={{
              fontSize: 11, color: t.inkMute, paddingLeft: 66, fontWeight: 500,
            }}>+{events.length - 2} more</div>
          )}
        </div>
      )}
    </div>
  );
}

// ── CALENDAR ──
function IosCalendarView({ mode = 'light' }) {
  const t = I_TOKENS[mode];
  const d = window.LinoJData;
  const NOW = 11.3;
  const [selectedDay, setSelectedDay] = React.useState('Tue');

  const dayEvents = d.events.filter(e => e.day === selectedDay).sort((a,b) => a.start - b.start);
  const selectedDayMeta = d.weekDays.find(w => w.key === selectedDay);

  return (
    <div style={{
      position: 'absolute', inset: 0,
      background: t.bg, color: t.ink,
      paddingBottom: 110, overflow: 'auto',
    }}>
      <IosTopActions mode={mode}/>

      <div style={{ padding: '64px 20px 14px' }}>
        <div style={{
          fontFamily: I_DISPLAY, fontSize: 34, fontWeight: 700,
          letterSpacing: '-0.03em', color: t.ink, lineHeight: 1,
        }}>Calendar</div>
        <div style={{
          fontSize: 13.5, color: t.inkSoft, marginTop: 6, fontWeight: 500,
        }}>
          <b style={{ color: t.ink, fontWeight: 600 }}>{d.events.length}</b> events · next 7 days
        </div>
      </div>

      {/* 7-day strip */}
      <div style={{
        padding: '0 14px', marginBottom: 14,
        display: 'flex', gap: 6,
        overflowX: 'auto',
      }}>
        {d.weekDays.map(day => {
          const isSelected = day.key === selectedDay;
          const dayCount = d.events.filter(e => e.day === day.key).length;
          return (
            <button key={day.key} onClick={() => setSelectedDay(day.key)}
              style={{
                flex: 1, minWidth: 46,
                padding: '8px 4px 10px',
                background: isSelected ? t.ink : 'transparent',
                color: isSelected ? t.bg : t.ink,
                border: `0.5px solid ${isSelected ? t.ink : t.border}`,
                borderRadius: 12,
                display: 'flex', flexDirection: 'column',
                alignItems: 'center', gap: 2,
                cursor: 'pointer',
              }}>
              <div style={{
                fontSize: 10, fontWeight: 600,
                color: isSelected ? t.bg : t.inkMute,
                textTransform: 'uppercase', letterSpacing: '0.06em',
                opacity: isSelected ? 0.7 : 1,
              }}>{day.label}</div>
              <div style={{
                fontFamily: I_DISPLAY, fontSize: 18, fontWeight: 700,
                letterSpacing: '-0.02em',
              }}>{day.date}</div>
              <div style={{
                width: 4, height: 4, borderRadius: '50%',
                background: dayCount > 0
                  ? (isSelected ? t.bg : t.ink)
                  : 'transparent',
                opacity: dayCount > 0 ? (isSelected ? 0.8 : 0.6) : 0,
              }}/>
            </button>
          );
        })}
      </div>

      {/* Day header */}
      <div style={{
        padding: '0 20px 8px',
        display: 'flex', alignItems: 'baseline', gap: 10,
      }}>
        <div style={{
          fontFamily: I_DISPLAY, fontSize: 17, fontWeight: 700,
          letterSpacing: '-0.015em',
        }}>
          {selectedDayMeta?.today ? 'Today' :
           selectedDay === 'Wed' ? 'Tomorrow' :
           `${selectedDayMeta?.label}, May ${selectedDayMeta?.date}`}
        </div>
        <div style={{ fontSize: 12.5, color: t.inkMute, fontWeight: 500 }}>
          {dayEvents.length} event{dayEvents.length !== 1 ? 's' : ''}
        </div>
      </div>

      {/* Day timeline */}
      <div style={{
        padding: '0 16px',
        display: 'flex', flexDirection: 'column', gap: 10,
      }}>
        {dayEvents.length === 0 && (
          <div style={{
            padding: '40px 0', textAlign: 'center', fontSize: 13.5,
            color: t.inkDim, fontStyle: 'italic', fontWeight: 500,
          }}>Nothing on the books.</div>
        )}
        {dayEvents.map(e => {
          const isPast = selectedDayMeta?.today && e.end < NOW;
          const isNow = selectedDayMeta?.today && e.start <= NOW && e.end > NOW;
          return (
            <IosEventCard key={e.id} event={e} mode={mode}
              isPast={isPast} isNow={isNow}/>
          );
        })}
      </div>

      {/* Yesterday missed */}
      {selectedDayMeta?.today && (
        <div style={{ padding: '20px 16px 0' }}>
          <IosYesterdayMissed mode={mode}/>
        </div>
      )}

      <IosTabBar active="calendar" mode={mode}/>
    </div>
  );
}

function IosEventCard({ event, mode, isPast, isNow }) {
  const t = I_TOKENS[mode];
  const project = event.project && window.LinoJData.projects.find(p => p.id === event.project);
  return (
    <div style={{
      background: t.panel,
      border: `0.5px solid ${isNow ? t.borderStrong : t.border}`,
      borderRadius: 14,
      padding: '12px 14px 12px 16px',
      display: 'flex', flexDirection: 'column', gap: 6,
      opacity: isPast ? 0.5 : 1,
      position: 'relative',
      overflow: 'hidden',
    }}>
      <div style={{
        position: 'absolute', left: 0, top: 10, bottom: 10,
        width: 3, background: t.ink, borderRadius: 2,
      }}/>
      <div style={{
        display: 'flex', alignItems: 'baseline', gap: 8,
      }}>
        <div style={{
          fontFamily: I_MONO, fontSize: 12, color: t.ink, fontWeight: 600,
          letterSpacing: '-0.01em',
        }}>{window.AFmtTime(event.start)}</div>
        <div style={{
          fontFamily: I_MONO, fontSize: 11, color: t.inkMute,
        }}>—{window.AFmtTime(event.end)}</div>
        {isNow && (
          <div style={{
            fontFamily: I_MONO, fontSize: 9, fontWeight: 700,
            color: t.bg, marginLeft: 'auto',
            padding: '2px 7px', background: t.ink, borderRadius: 4,
            textTransform: 'uppercase', letterSpacing: '0.06em',
          }}>now</div>
        )}
      </div>
      <div style={{
        fontSize: 15, fontWeight: 600, color: t.ink,
        letterSpacing: '-0.01em', lineHeight: 1.3,
      }}>{event.title}</div>
      <div style={{
        fontSize: 12.5, color: t.inkSoft, fontWeight: 500,
      }}>{event.where}</div>
      {(event.who.length > 0 || project) && (
        <div style={{
          display: 'flex', alignItems: 'center', gap: 8,
          marginTop: 4,
        }}>
          {event.who.length > 0 && (
            <div style={{ display: 'flex' }}>
              {event.who.slice(0, 4).map((m, i) => (
                <div key={i} style={{
                  marginLeft: i === 0 ? 0 : -5,
                  borderRadius: '50%', border: `1.5px solid ${t.panel}`,
                }}>
                  <AAvatar name={m} size={20} mode={mode}/>
                </div>
              ))}
            </div>
          )}
          {project && (
            <div style={{
              fontSize: 11, color: t.inkMute, fontWeight: 500,
              padding: '2px 7px', borderRadius: 4, background: t.chip,
            }}>{project.title}</div>
          )}
        </div>
      )}
    </div>
  );
}

function IosYesterdayMissed({ mode }) {
  const t = I_TOKENS[mode];
  const d = window.LinoJData;
  const [doneSet, setDoneSet] = React.useState(new Set());
  const toggle = (id) => setDoneSet(s => {
    const n = new Set(s); n.has(id) ? n.delete(id) : n.add(id); return n;
  });
  if (!d.yesterdayEvents.length) return null;

  return (
    <div style={{
      background: t.chip,
      borderRadius: 14,
      padding: '14px 14px',
    }}>
      <div style={{
        display: 'flex', alignItems: 'baseline', gap: 8, marginBottom: 8,
      }}>
        <div style={{
          fontSize: 11, fontWeight: 700, color: t.inkMute,
          textTransform: 'uppercase', letterSpacing: '0.08em',
        }}>From yesterday</div>
        <div style={{ fontSize: 11, color: t.inkDim, fontWeight: 500 }}>· May 26</div>
        <div style={{ flex: 1 }}/>
        <div style={{ fontSize: 10.5, color: t.inkMute, fontStyle: 'italic' }}>tap to confirm</div>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
        {d.yesterdayEvents.map(e => {
          const done = doneSet.has(e.id);
          return (
            <div key={e.id} style={{
              display: 'flex', alignItems: 'flex-start', gap: 10,
              padding: '6px 0', opacity: done ? 0.4 : 1,
            }} onClick={() => toggle(e.id)}>
              <div style={{ paddingTop: 1 }}>
                <ACheckbox done={done} mode={mode} size={14}/>
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{
                  fontSize: 13, fontWeight: 500, color: t.inkSoft,
                  letterSpacing: '-0.005em',
                  textDecoration: done ? 'line-through' : 'none',
                }}>{e.title}</div>
                <div style={{
                  fontSize: 10.5, color: t.inkMute, marginTop: 2,
                  fontFamily: I_MONO, fontWeight: 500,
                }}>{window.AFmtTime(e.start)} · {e.where}</div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

Object.assign(window, {
  IosPersonalView, IosCompanyView, IosCalendarView,
  IosCompletedBox, IosProjectDetailCard, IosEventCard, IosYesterdayMissed,
});
