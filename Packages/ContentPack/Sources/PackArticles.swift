/// The v1 curated articles: short fixture passages *derived from* ACOG and NICE
/// public guidance, paraphrased editorially for the pack. Compiled in at build
/// time, versioned, never fetched (invariant #1). Perimenopause-weighted per
/// DESIGN.md M2. No diagnosis or contraception-efficacy language (invariant #5).
///
/// Citation ids and section anchors are stable forever — content edits bump the
/// pack version, never the ids.
public enum PackArticles {
    public static let v1: [ContentChunk] = [
        perimenopauseOverview,
        cycleLengthVariation,
        menopauseIdentification,
        heavyBleeding,
        ovulationTiming,
    ]

    static let perimenopauseOverview = ContentChunk(
        id: "acog-perimenopause-overview-001",
        source: .acog,
        title: "The menopausal transition (ACOG-derived)",
        passage: "Perimenopause is the transition toward the final menstrual period. "
            + "It commonly begins in the 40s and can last several years.",
        packVersion: ContentPackStore.version,
        sections: [
            ContentSection(
                anchor: "what-it-is",
                heading: "What perimenopause is",
                text: "Perimenopause is the years-long transition before the final "
                    + "menstrual period, commonly beginning in the 40s. Hormone levels "
                    + "shift unevenly during this time rather than declining smoothly."
            ),
            ContentSection(
                anchor: "cycle-changes",
                heading: "How cycles change",
                text: "Cycles often become shorter or longer and less predictable during "
                    + "the transition. Skipped cycles and changes in flow are common as "
                    + "ovulation becomes less regular."
            ),
            ContentSection(
                anchor: "common-symptoms",
                heading: "Common symptoms",
                text: "Hot flashes, night sweats, sleep disruption, mood changes, and "
                    + "difficulty concentrating are frequently reported during the "
                    + "menopausal transition. Patterns differ widely between people."
            ),
        ]
    )

    static let cycleLengthVariation = ContentChunk(
        id: "acog-cycle-variation-001",
        source: .acog,
        title: "Menstrual cycle length and variation (ACOG-derived)",
        passage: "Cycle length varies between people and from cycle to cycle; "
            + "a range of roughly 21 to 35 days is common in adults.",
        packVersion: ContentPackStore.version,
        sections: [
            ContentSection(
                anchor: "typical-range",
                heading: "Typical range",
                text: "Adult menstrual cycles commonly run from about 21 to 35 days, "
                    + "counted from the first day of one period to the first day of the "
                    + "next. Some variation from cycle to cycle is normal."
            ),
            ContentSection(
                anchor: "variation-by-age",
                heading: "Variation across life stages",
                text: "Cycles are often more variable in the years after the first period "
                    + "and again in the years approaching menopause, when shorter, longer, "
                    + "or skipped cycles become more common."
            ),
            ContentSection(
                anchor: "when-to-seek-care",
                heading: "When to bring it to a clinician",
                text: "A persistent change from your own usual pattern — much heavier "
                    + "flow, bleeding between periods, or cycles stopping unexpectedly — "
                    + "is worth discussing with a clinician."
            ),
        ]
    )

    static let menopauseIdentification = ContentChunk(
        id: "nice-menopause-ng23-001",
        source: .nice,
        title: "Menopause: identification and care (NICE NG23-derived)",
        passage: "Guidance recognises perimenopause from a pattern of irregular "
            + "cycles and vasomotor symptoms, with care centred on the person's "
            + "own symptom record.",
        packVersion: ContentPackStore.version,
        sections: [
            ContentSection(
                anchor: "vasomotor-symptoms",
                heading: "Vasomotor symptoms",
                text: "Hot flashes and night sweats are the hallmark vasomotor symptoms "
                    + "of the menopausal transition. Their frequency and intensity vary "
                    + "and a personal symptom record helps describe the pattern."
            ),
            ContentSection(
                anchor: "sleep-and-mood",
                heading: "Sleep and mood",
                text: "Sleep disturbance and low mood are commonly reported alongside "
                    + "cycle changes in the transition. Tracking when they cluster "
                    + "relative to cycles gives a clinician useful context."
            ),
            ContentSection(
                anchor: "talking-to-clinician",
                heading: "Preparing for an appointment",
                text: "A dated record of cycles, flow, and symptoms over recent months is "
                    + "one of the most useful things to bring to an appointment about the "
                    + "menopausal transition."
            ),
        ]
    )

    static let heavyBleeding = ContentChunk(
        id: "nice-heavy-bleeding-ng88-001",
        source: .nice,
        title: "Heavy menstrual bleeding (NICE NG88-derived)",
        passage: "Heavy menstrual bleeding is bleeding that interferes with daily "
            + "life; a personal bleeding record anchors any conversation about it.",
        packVersion: ContentPackStore.version,
        sections: [
            ContentSection(
                anchor: "what-counts-as-heavy",
                heading: "What counts as heavy",
                text: "Heavy menstrual bleeding is defined by its impact: bleeding that "
                    + "interferes with physical, social, or emotional quality of life, "
                    + "rather than by a fixed volume."
            ),
            ContentSection(
                anchor: "tracking-helps",
                heading: "Why a bleeding record helps",
                text: "A day-by-day record of flow intensity across recent cycles gives a "
                    + "clearer picture than recall alone and supports a more useful "
                    + "conversation with a clinician."
            ),
            ContentSection(
                anchor: "when-to-seek-care",
                heading: "When to seek care",
                text: "Bleeding that soaks through protection hourly, lasts much longer "
                    + "than usual, or comes with feeling faint or exhausted should be "
                    + "raised with a clinician promptly."
            ),
        ]
    )

    static let ovulationTiming = ContentChunk(
        id: "acog-ovulation-timing-001",
        source: .acog,
        title: "Ovulation and cycle timing (ACOG-derived)",
        passage: "Ovulation typically precedes the next period by about two weeks; "
            + "the luteal phase is more consistent than the cycle overall.",
        packVersion: ContentPackStore.version,
        sections: [
            ContentSection(
                anchor: "luteal-phase",
                heading: "The luteal phase",
                text: "The luteal phase — from ovulation to the next period — is "
                    + "typically around two weeks and varies less than total cycle "
                    + "length, which is why ovulation estimates count back from the "
                    + "predicted period."
            ),
            ContentSection(
                anchor: "cycle-tracking",
                heading: "What tracking can and cannot tell you",
                text: "Cycle records estimate a window of likely ovulation days, not a "
                    + "certain day. Estimates are ranges, and any forecast should be read "
                    + "as one."
            ),
            ContentSection(
                anchor: "signs-of-ovulation",
                heading: "Signals around ovulation",
                text: "Changes in basal body temperature and cervical fluid, and a "
                    + "luteinising-hormone rise on test strips, tend to cluster around "
                    + "ovulation; individual patterns differ."
            ),
        ]
    )
}
