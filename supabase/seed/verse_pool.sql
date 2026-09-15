-- supabase/seed/verse_pool.sql
--
-- Seeds public.verse_pool, which schema.sql creates empty. Run this
-- after schema.sql. Safe to re-run: uses (reference, translation) as a
-- de-dupe key via a temporary unique index check.
--
-- Text is KJV (public domain), so it can ship in the repo without a
-- license concern. Swap translation/text for a licensed version later
-- if the app needs one — just re-seed with the new rows.

insert into public.verse_pool (reference, text, translation, tags)
values
  ('John 3:16', 'For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.', 'KJV', array['love','salvation','gospel']),
  ('Psalm 23:1', 'The LORD is my shepherd; I shall not want.', 'KJV', array['comfort','trust']),
  ('Philippians 4:13', 'I can do all things through Christ which strengtheneth me.', 'KJV', array['strength','perseverance']),
  ('Jeremiah 29:11', 'For I know the thoughts that I think toward you, saith the LORD, thoughts of peace, and not of evil, to give you an expected end.', 'KJV', array['hope','future']),
  ('Proverbs 3:5-6', 'Trust in the LORD with all thine heart; and lean not unto thine own understanding. In all thy ways acknowledge him, and he shall direct thy paths.', 'KJV', array['trust','guidance']),
  ('Romans 8:28', 'And we know that all things work together for good to them that love God, to them who are the called according to his purpose.', 'KJV', array['hope','providence']),
  ('Isaiah 41:10', 'Fear thou not; for I am with thee: be not dismayed; for I am thy God: I will strengthen thee; yea, I will help thee; yea, I will uphold thee with the right hand of my righteousness.', 'KJV', array['courage','comfort']),
  ('Joshua 1:9', 'Have not I commanded thee? Be strong and of a good courage; be not afraid, neither be thou dismayed: for the LORD thy God is with thee whithersoever thou goest.', 'KJV', array['courage','presence']),
  ('Psalm 46:1', 'God is our refuge and strength, a very present help in trouble.', 'KJV', array['comfort','trust']),
  ('Matthew 6:33', 'But seek ye first the kingdom of God, and his righteousness; and all these things shall be added unto you.', 'KJV', array['priorities','provision']),
  ('Galatians 5:22-23', 'But the fruit of the Spirit is love, joy, peace, longsuffering, gentleness, goodness, faith, meekness, temperance: against such there is no law.', 'KJV', array['spirit','character']),
  ('Romans 12:2', 'And be not conformed to this world: but be ye transformed by the renewing of your mind, that ye may prove what is that good, and acceptable, and perfect, will of God.', 'KJV', array['renewal','discernment']),
  ('Psalm 119:105', 'Thy word is a lamp unto my feet, and a light unto my path.', 'KJV', array['scripture','guidance']),
  ('1 Corinthians 13:4-7', 'Charity suffereth long, and is kind; charity envieth not; charity vaunteth not itself, is not puffed up, Doth not behave itself unseemly, seeketh not her own, is not easily provoked, thinketh no evil; Rejoiceth not in iniquity, but rejoiceth in the truth; Beareth all things, believeth all things, hopeth all things, endureth all things.', 'KJV', array['love']),
  ('Matthew 11:28', 'Come unto me, all ye that labour and are heavy laden, and I will give you rest.', 'KJV', array['rest','comfort']),
  ('Deuteronomy 31:6', 'Be strong and of a good courage, fear not, nor be afraid of them: for the LORD thy God, he it is that doth go with thee; he will not fail thee, nor forsake thee.', 'KJV', array['courage','presence']),
  ('Psalm 34:18', 'The LORD is nigh unto them that are of a broken heart; and saveth such as be of a contrite spirit.', 'KJV', array['comfort','grief']),
  ('Ephesians 2:8-9', 'For by grace are ye saved through faith; and that not of yourselves: it is the gift of God: Not of works, lest any man should boast.', 'KJV', array['grace','salvation']),
  ('James 1:2-3', 'My brethren, count it all joy when ye fall into divers temptations; Knowing this, that the trying of your faith worketh patience.', 'KJV', array['trials','perseverance']),
  ('Psalm 121:1-2', 'I will lift up mine eyes unto the hills, from whence cometh my help. My help cometh from the LORD, which made heaven and earth.', 'KJV', array['help','trust']),
  ('2 Timothy 1:7', 'For God hath not given us the spirit of fear; but of power, and of love, and of a sound mind.', 'KJV', array['courage','identity']),
  ('Colossians 3:23', 'And whatsoever ye do, do it heartily, as to the Lord, and not unto men.', 'KJV', array['work','purpose']),
  ('Psalm 27:1', 'The LORD is my light and my salvation; whom shall I fear? the LORD is the strength of my life; of whom shall I be afraid?', 'KJV', array['courage','trust']),
  ('Hebrews 11:1', 'Now faith is the substance of things hoped for, the evidence of things not seen.', 'KJV', array['faith']),
  ('Proverbs 17:17', 'A friend loveth at all times, and a brother is born for adversity.', 'KJV', array['friendship','community']),
  ('Matthew 5:14-16', 'Ye are the light of the world. A city that is set on an hill cannot be hid. Neither do men light a candle, and put it under a bushel, but on a candlestick; and it giveth light unto all that are in the house. Let your light so shine before men, that they may see your good works, and glorify your Father which is in heaven.', 'KJV', array['witness','purpose']),
  ('Psalm 139:14', 'I will praise thee; for I am fearfully and wonderfully made: marvellous are thy works; and that my soul knoweth right well.', 'KJV', array['identity','worth']),
  ('Isaiah 40:31', 'But they that wait upon the LORD shall renew their strength; they shall mount up with wings as eagles; they shall run, and not be weary; and they shall walk, and not faint.', 'KJV', array['strength','patience']),
  ('John 14:27', 'Peace I leave with you, my peace I give unto you: not as the world giveth, give I unto you. Let not your heart be troubled, neither let it be afraid.', 'KJV', array['peace','comfort']),
  ('Philippians 4:6-7', 'Be careful for nothing; but in every thing by prayer and supplication with thanksgiving let your requests be made known unto God. And the peace of God, which passeth all understanding, shall keep your hearts and minds through Christ Jesus.', 'KJV', array['peace','prayer'])
on conflict (reference, translation) do nothing;
