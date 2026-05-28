// ===============================================================
// Empty states — macOS + iOS
// ===============================================================

// ── Empty art: simple geometric mark ──
function EmptyArt({ size = 72, mode = 'light', kind = 'check' }) {
  const t = A_TOKENS[mode];
  const stroke = t.inkMute;
  const fill = t.chip;

  if (kind === 'check') return (
    <svg width={size} height={size} viewBox="0 0 72 72" fill="none">
      <circle cx="36" cy="36" r="28" stroke={stroke} strokeWidth="1.5" strokeDasharray="3 5"/>
      <path d="M24 36l9 9 16-18" stroke={t.ink} strokeWidth="2.2"
        fill="none" strokeLinecap="round" strokeLinejoin="round" opacity="0.45"/>
    </svg>
  );
  if (kind === 'sparkle') return (
    <svg width={size} height={size} viewBox="0 0 72 72" fill="none">
      <path d="M36 14v8M36 50v8M14 36h8M50 36h8M22 22l5 5M50 50l-5-5M22 50l5-5M50 22l-5 5"
        stroke={stroke} strokeWidth="1.5" strokeLinecap="round"/>
      <circle cx="36" cy="36" r="7" fill={t.ink} opacity="0.18"/>
      <circle cx="36" cy="36" r="3.5" fill={t.ink} opacity="0.45"/>
    </svg>
  );
  if (kind === 'calendar') return (
    <svg width={size} height={size} viewBox="0 0 72 72" fill="none">
      <rect x="14" y="20" width="44" height="40" rx="5" stroke={stroke} strokeWidth="1.5"/>
      <line x1="14" y1="30" x2="58" y2="30" stroke={stroke} strokeWidth="1.5"/>
      <line x1="24" y1="14" x2="24" y2="24" stroke={stroke} strokeWidth="1.5" strokeLinecap="round"/>
      <line x1="48" y1="14" x2="48" y2="24" stroke={stroke} strokeWidth="1.5" strokeLinecap="round"/>
      <circle cx="36" cy="44" r="3" fill={t.ink} opacity="0.3"/>
    </svg>
  );
  if (kind === 'search') return (
    <svg width={size} height={size} viewBox="0 0 72 72" fill="none">
      <circle cx="32" cy="32" r="14" stroke={stroke} strokeWidth="1.8"/>
      <path d="M44 44L56 56" stroke={stroke} strokeWidth="1.8" strokeLinecap="round"/>
      <line x1="26" y1="32" x2="38" y2="32" stroke={t.ink} strokeWidth="1.5" opacity="0.4"/>
    </svg>
  );
  if (kind === 'folder') return (
    <svg width={size} height={size} viewBox="0 0 72 72" fill="none">
      <path d="M14 22h16l5 5h23v25a3 3 0 01-3 3H17a3 3 0 01-3-3V22z"
        stroke={stroke} strokeWidth="1.6" strokeLinejoin="round"/>
      <circle cx="36" cy="40" r="3" fill={t.ink} opacity="0.3"/>
    </svg>
  );
  return null;
}

// ── Generic centered empty block ──
function EmptyBlock({ kind, title, subtitle, cta, mode = 'light', compact, ios }) {
  const t = (ios ? I_TOKENS : A_TOKENS)[mode];
  const FONT = ios ? I_FONT : A_FONT;
  const DISPLAY = ios ? I_DISPLAY : A_DISPLAY;
  return (
    <div style={{
      display: 'flex', flexDirection: 'column', alignItems: 'center',
      gap: 14, padding: compact ? '24px 20px' : '40px 24px',
      textAlign: 'center',
    }}>
      <EmptyArt size={compact ? 56 : 72} mode={mode} kind={kind}/>
      <div style={{
        fontFamily: DISPLAY,
        fontSize: compact ? 16 : 19,
        fontWeight: 600,
        letterSpacing: '-0.02em',
        color: t.ink,
      }}>{title}</div>
      <div style={{
        fontSize: compact ? 12.5 : 13.5,
        color: t.inkSoft, fontWeight: 500, lineHeight: 1.5,
        maxWidth: 320, marginTop: -6,
      }}>{subtitle}</div>
      {cta && (
        <button style={{
          background: t.ink, color: t.bg, border: 'none', cursor: 'pointer',
          padding: '7px 14px', borderRadius: 8,
          fontSize: 12.5, fontWeight: 600, fontFamily: FONT,
          marginTop: 4,
        }}>{cta}</button>
      )}
    </div>
  );
}

// ===============================================================
// macOS — empty Main (first run / inbox zero)
// ===============================================================
function AMainViewEmpty({ mode = 'light' }) {
  const t = A_TOKENS[mode];
  return (
    <div style={{
      width: '100%', height: '100%',
      display: 'grid', gridTemplateColumns: '1fr 360px',
      background: t.bg, color: t.ink, overflow: 'hidden',
    }}>
      <div style={{
        padding: '20px 28px 22px',
        display: 'flex', flexDirection: 'column', gap: 16,
        minHeight: 0, overflow: 'hidden',
      }}>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 16 }}>
          <div style={{
            fontFamily: A_DISPLAY, fontSize: 26, fontWeight: 600,
            letterSpacing: '-0.025em', color: t.ink, lineHeight: 1,
          }}>To do</div>
          <div style={{ fontSize: 13, color: t.inkSoft, fontWeight: 500 }}>
            <b style={{ color: t.ink, fontWeight: 600 }}>0</b> open
          </div>
        </div>

        <div style={{
          flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center',
          minHeight: 0,
        }}>
          <EmptyBlock
            kind="check"
            mode={mode}
            title="Inbox zero."
            subtitle="No urgent or normal todos right now. Capture something new with \u2318N \u2014 or take an actual break."
            cta="+ New todo"
          />
        </div>

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
              0 active
            </div>
          </div>
          <div style={{
            border: `0.5px dashed ${t.borderStrong}`, borderRadius: 12,
            padding: '14px', textAlign: 'center',
            fontSize: 12.5, color: t.inkMute, fontWeight: 500,
          }}>
            No projects yet \u00b7{' '}
            <span style={{ color: t.ink, fontWeight: 600, cursor: 'pointer' }}>
              Start one \u2192
            </span>
          </div>
        </div>
      </div>

      {/* Right rail */}
      <div style={{
        borderLeft: `0.5px solid ${t.border}`,
        padding: '20px 18px',
        display: 'flex', flexDirection: 'column',
      }}>
        <div style={{
          fontFamily: A_DISPLAY, fontSize: 16, fontWeight: 600,
          letterSpacing: '-0.015em', marginBottom: 16,
        }}>Next 7 days</div>
        <EmptyBlock
          kind="calendar"
          mode={mode}
          compact
          title="Nothing on the books."
          subtitle="A calm week. Block something in Calendar when needed."
        />
      </div>
    </div>
  );
}

// ── macOS Personal urgent empty (partial) ──
function APersonalViewEmpty({ mode = 'light' }) {
  const t = A_TOKENS[mode];
  const d = window.LinoJData;
  // Pretend personal has only normal items, no urgent
  const normal = d.personalTodos.filter(x => x.urgency === 'normal' && !x.done).slice(0, 3);
  return (
    <div style={{
      width: '100%', height: '100%', overflow: 'auto',
      background: t.bg, color: t.ink, padding: '24px 32px 32px',
    }}>
      <div style={{ display: 'flex', alignItems: 'flex-end', gap: 16, marginBottom: 22 }}>
        <div>
          <div style={{
            fontFamily: A_DISPLAY, fontSize: 28, fontWeight: 600,
            letterSpacing: '-0.025em', lineHeight: 1.05,
          }}>Personal</div>
          <div style={{
            fontSize: 13, color: t.inkSoft, marginTop: 6, fontWeight: 500,
          }}>
            <b style={{ color: t.ink, fontWeight: 600 }}>{normal.length}</b> open \u00b7 0 urgent
          </div>
        </div>
      </div>

      <div style={{
        display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 18, maxWidth: 1100,
      }}>
        {/* Urgent — empty */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <div style={{
            display: 'flex', alignItems: 'baseline', gap: 10, paddingLeft: 2,
          }}>
            <div style={{
              width: 8, height: 8, borderRadius: '50%', background: t.blue,
              opacity: 0.35,
            }}/>
            <div style={{
              fontFamily: A_DISPLAY, fontSize: 17, fontWeight: 600,
              color: t.inkMute, letterSpacing: '-0.015em',
            }}>Urgent</div>
            <div style={{ fontSize: 12, color: t.inkMute, fontWeight: 500 }}>0</div>
          </div>
          <div style={{
            border: `0.5px dashed ${t.borderStrong}`, borderRadius: 12,
            padding: '24px 14px', textAlign: 'center',
            display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6,
            minHeight: 160, justifyContent: 'center',
          }}>
            <div style={{
              fontSize: 13.5, fontWeight: 600, color: t.ink, letterSpacing: '-0.005em',
            }}>Nothing urgent.</div>
            <div style={{ fontSize: 12, color: t.inkSoft, fontWeight: 500 }}>
              Nice.
            </div>
          </div>
        </div>

        <ABubbleColumn label="Normal" tier="normal"
          count={normal.length} items={normal}
          doneSet={new Set()} toggle={() => {}} mode={mode}/>
      </div>
    </div>
  );
}

// ── macOS Calendar empty week ──
function ACalendarViewEmpty({ mode = 'light' }) {
  const t = A_TOKENS[mode];
  const d = window.LinoJData;
  const startHour = 7, endHour = 21;
  const hours = endHour - startHour;
  const pxPerHour = 46;

  return (
    <div style={{
      width: '100%', height: '100%', overflow: 'hidden',
      background: t.bg, color: t.ink,
      display: 'flex', flexDirection: 'column', padding: '22px 28px 0',
    }}>
      <div style={{
        display: 'flex', alignItems: 'flex-end', gap: 12, marginBottom: 16,
      }}>
        <div>
          <div style={{
            fontFamily: A_DISPLAY, fontSize: 26, fontWeight: 600,
            letterSpacing: '-0.025em', lineHeight: 1.05,
          }}>Calendar</div>
          <div style={{ fontSize: 12.5, color: t.inkSoft, marginTop: 6, fontWeight: 500 }}>
            <b style={{ color: t.ink, fontWeight: 600 }}>0</b> events \u00b7 next 7 days
          </div>
        </div>
        <div style={{ flex: 1 }}/>
        <button style={{
          background: t.ink, color: t.bg, border: 'none', cursor: 'pointer',
          padding: '6px 12px', borderRadius: 7,
          fontSize: 12.5, fontWeight: 600, fontFamily: A_FONT,
        }}>+ New event</button>
      </div>

      {/* Day headers */}
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
            }}>{day.date}</div>
          </div>
        ))}
      </div>

      {/* Grid (empty, with center message) */}
      <div style={{
        flex: 1, position: 'relative', overflow: 'hidden',
      }}>
        <div style={{
          display: 'grid', gridTemplateColumns: '52px repeat(7, 1fr)',
          position: 'absolute', inset: 0,
        }}>
          <div/>
          {d.weekDays.map(day => (
            <div key={day.key} style={{
              borderLeft: `0.5px solid ${t.border}`,
              background: day.today ? (mode === 'light' ? 'rgba(0,0,0,0.02)' : 'rgba(255,255,255,0.025)') : 'transparent',
            }}/>
          ))}
        </div>
        <div style={{
          position: 'absolute', inset: 0,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <EmptyBlock
            kind="calendar"
            mode={mode}
            title="A clear week."
            subtitle="No meetings, no appointments. Block an event when something needs a time, place, and people."
            cta="+ New event"
          />
        </div>
      </div>
    </div>
  );
}

// ── macOS Search no results ──
function ASearchPaletteEmpty({ mode = 'light' }) {
  const t = A_TOKENS[mode];
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
        background: t.panel, color: t.ink, borderRadius: 14,
        boxShadow: '0 24px 80px rgba(0,0,0,0.45), 0 0 0 0.5px rgba(0,0,0,0.18)',
        overflow: 'hidden', fontFamily: A_FONT,
      }}>
        <div style={{
          display: 'flex', alignItems: 'center', gap: 12,
          padding: '14px 18px',
          borderBottom: `0.5px solid ${t.border}`,
        }}>
          <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
            <circle cx="7" cy="7" r="4.5" stroke={t.inkSoft} strokeWidth="1.4"/>
            <path d="M10.3 10.3L14 14" stroke={t.inkSoft} strokeWidth="1.4" strokeLinecap="round"/>
          </svg>
          <input autoFocus defaultValue="renovate the moon"
            style={{
              flex: 1, background: 'transparent', border: 'none', outline: 'none',
              fontFamily: A_FONT, fontSize: 15, fontWeight: 500,
              color: t.ink, letterSpacing: '-0.005em',
            }}/>
        </div>
        <EmptyBlock
          kind="search"
          mode={mode}
          title='No matches for "renovate the moon."'
          subtitle="Try a shorter phrase, or jump to a section: Personal, Company, Calendar."
        />
        <div style={{
          padding: '10px 16px',
          borderTop: `0.5px solid ${t.border}`,
          fontSize: 11, color: t.inkMute, fontWeight: 500,
          display: 'flex', gap: 14,
        }}>
          <span><kbd style={{
            fontFamily: A_MONO, fontSize: 10.5, padding: '1px 6px',
            background: t.chip, borderRadius: 3, marginRight: 4, fontWeight: 600,
          }}>esc</kbd>close</span>
          <span><kbd style={{
            fontFamily: A_MONO, fontSize: 10.5, padding: '1px 6px',
            background: t.chip, borderRadius: 3, marginRight: 4, fontWeight: 600,
          }}>\u2318N</kbd>create one</span>
        </div>
      </div>
    </div>
  );
}

// ===============================================================
// iOS empty states
// ===============================================================
function IosMainViewEmpty({ mode = 'light' }) {
  const t = I_TOKENS[mode];
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
        }}>To do</div>
        <div style={{
          fontSize: 13.5, color: t.inkSoft, marginTop: 6, fontWeight: 500,
        }}>
          <b style={{ color: t.ink, fontWeight: 600 }}>0</b> open
          <span style={{ color: t.inkDim, margin: '0 7px' }}>\u00b7</span>
          A calm day.
        </div>
      </div>

      <div style={{ padding: '40px 16px 0' }}>
        <EmptyBlock
          ios
          kind="check"
          mode={mode}
          title="You're caught up."
          subtitle="Nothing urgent or normal in your list. Add one when something needs doing."
          cta="+ New todo"
        />
      </div>

      <div style={{ padding: '24px 16px 0' }}>
        <div style={{
          background: t.panel, border: `0.5px dashed ${t.borderStrong}`,
          borderRadius: 14, padding: '20px 14px',
          textAlign: 'center',
        }}>
          <div style={{
            fontFamily: I_DISPLAY, fontSize: 14, fontWeight: 600,
            color: t.ink, letterSpacing: '-0.005em',
          }}>No projects yet</div>
          <div style={{
            fontSize: 12, color: t.inkSoft, marginTop: 4, fontWeight: 500,
          }}>Buckets of work live in Company.</div>
        </div>
      </div>

      <IosTabBar active="main" mode={mode}/>
    </div>
  );
}

function IosCalendarViewEmpty({ mode = 'light' }) {
  const t = I_TOKENS[mode];
  const d = window.LinoJData;
  const [selectedDay] = React.useState('Tue');

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
          <b style={{ color: t.ink, fontWeight: 600 }}>0</b> events \u00b7 next 7 days
        </div>
      </div>

      <div style={{
        padding: '0 14px', marginBottom: 14,
        display: 'flex', gap: 6, overflowX: 'auto',
      }}>
        {d.weekDays.map(day => {
          const isSelected = day.key === selectedDay;
          return (
            <button key={day.key} style={{
              flex: 1, minWidth: 46, padding: '8px 4px 10px',
              background: isSelected ? t.ink : 'transparent',
              color: isSelected ? t.bg : t.ink,
              border: `0.5px solid ${isSelected ? t.ink : t.border}`,
              borderRadius: 12,
              display: 'flex', flexDirection: 'column',
              alignItems: 'center', gap: 2, cursor: 'pointer',
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
                background: 'transparent',
              }}/>
            </button>
          );
        })}
      </div>

      <div style={{ padding: '40px 16px 0' }}>
        <EmptyBlock
          ios
          kind="calendar"
          mode={mode}
          title="A clear week."
          subtitle="No meetings, no appointments. Block an event when something needs a time, place, and people."
          cta="+ New event"
        />
      </div>

      <IosTabBar active="calendar" mode={mode}/>
    </div>
  );
}

function IosSearchScreenEmpty({ mode = 'light' }) {
  const t = I_TOKENS[mode];
  return (
    <div style={{
      position: 'absolute', inset: 0, zIndex: 100,
      background: t.bg, color: t.ink,
      display: 'flex', flexDirection: 'column',
    }}>
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
          <input autoFocus defaultValue="renovate the moon"
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
          }}>\u00d7</div>
        </div>
        <button style={{
          background: 'transparent', border: 'none', cursor: 'pointer',
          color: t.ink, fontSize: 15, fontWeight: 500,
          fontFamily: I_FONT, padding: 0,
        }}>Cancel</button>
      </div>
      <div style={{ flex: 1, padding: '40px 16px 0' }}>
        <EmptyBlock
          ios
          kind="search"
          mode={mode}
          title='No matches.'
          subtitle="Try a shorter phrase, or browse Personal / Company / Calendar."
        />
      </div>
    </div>
  );
}

Object.assign(window, {
  EmptyArt, EmptyBlock,
  AMainViewEmpty, APersonalViewEmpty, ACalendarViewEmpty, ASearchPaletteEmpty,
  IosMainViewEmpty, IosCalendarViewEmpty, IosSearchScreenEmpty,
});
