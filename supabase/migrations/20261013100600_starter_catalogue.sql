-- Starter catalogue for every environment, production included (D-062). Admins refine it
-- from the console afterwards; re-running inserts nothing new (on conflict do nothing).
--
-- Vehicles: common makes and models in Sudan, one row per generation and engine, year
-- ranges approximate for the Gulf/African market — shops should check them.
-- Parts: generic everyday parts with no fitment (shown as "check fitment"); shops add
-- their own parts and admins merge duplicates into these.
-- Synonyms: colloquial words are a first guess — TODO: confirm with the team (D-032).
-- Street and zones: placeholder names and no GPS origin — the owner sets them before launch.

-- ------------------------------------------------------------------ job types
insert into public.job_types (code, name_ar, name_en, sort) values
  ('LIGHTING',   'إضاءة',        'Lighting',          1),
  ('BRAKES',     'فرامل',        'Brakes',            2),
  ('SERVICE',    'صيانة دورية',  'Servicing',         3),
  ('BATTERY',    'بطاريات',      'Batteries',         4),
  ('ELECTRICAL', 'كهرباء',       'Electrical',        5),
  ('AC',         'تكييف',        'Air conditioning',  6),
  ('SUSPENSION', 'عفشة',         'Suspension',        7),
  ('TYRES',      'إطارات',       'Tyres',             8),
  ('MECHANICAL', 'ميكانيكا',     'Mechanical',        9)
on conflict (code) do nothing;

-- ------------------------------------------------------------------ categories
insert into public.part_categories (slug, name_ar, name_en, icon, job_type_id, std_job_minutes, sort)
select x.slug, x.ar, x.en, x.icon, jt.id, x.minutes, x.sort
from (values
  ('lighting',     'الإضاءة',            'Lighting',              'lighting',     'LIGHTING',   30,   1),
  ('brakes',       'الفرامل',            'Brakes',                'brakes',       'BRAKES',     60,   2),
  ('oil-filters',  'الزيوت والفلاتر',    'Oils & filters',        'oil',          'SERVICE',    30,   3),
  ('batteries',    'البطاريات',          'Batteries',             'battery',      'BATTERY',    20,   4),
  ('electrical',   'الكهرباء',           'Electrical',            'electrical',   'ELECTRICAL', 60,   5),
  ('ac',           'التكييف',            'Air conditioning',      'ac',           'AC',         90,   6),
  ('suspension',   'العفشة والتوجيه',    'Suspension & steering', 'suspension',   'SUSPENSION', 90,   7),
  ('tyres',        'الإطارات والجنوط',   'Tyres & wheels',        'tyres',        'TYRES',      30,   8),
  ('engine',       'المحرك والتبريد',    'Engine & cooling',      'engine',       'MECHANICAL', 90,   9),
  ('transmission', 'القير والكلتش',      'Gearbox & clutch',      'transmission', 'MECHANICAL', 180, 10),
  ('body',         'البودي والزجاج',     'Body & glass',          'body',         null,         null, 11),
  ('accessories',  'الإكسسوارات',        'Accessories',           'accessories',  null,         null, 12)
) as x(slug, ar, en, icon, job, minutes, sort)
left join public.job_types jt on jt.code = x.job
on conflict (slug) do nothing;

-- ------------------------------------------------------------------ makes
insert into public.vehicle_makes (slug, name_ar, name_en, sort) values
  ('toyota',      'تويوتا',       'Toyota',         1),
  ('hyundai',     'هيونداي',      'Hyundai',        2),
  ('kia',         'كيا',          'Kia',            3),
  ('nissan',      'نيسان',        'Nissan',         4),
  ('mitsubishi',  'ميتسوبيشي',    'Mitsubishi',     5),
  ('isuzu',       'إيسوزو',       'Isuzu',          6),
  ('suzuki',      'سوزوكي',       'Suzuki',         7),
  ('honda',       'هوندا',        'Honda',          8),
  ('mercedes',    'مرسيدس بنز',   'Mercedes-Benz',  9),
  ('ford',        'فورد',         'Ford',          10),
  ('geely',       'جيلي',         'Geely',         11),
  ('chery',       'شيري',         'Chery',         12),
  ('great-wall',  'جريت وول',     'Great Wall',    13)
on conflict (slug) do nothing;

-- ------------------------------------------------------------------ models
insert into public.vehicle_models (make_id, slug, name_ar, name_en, sort)
select mk.id, x.slug, x.ar, x.en, x.sort
from (values
  ('toyota',     'hilux',            'هايلكس',              'Hilux',              1),
  ('toyota',     'land-cruiser',     'لاندكروزر',           'Land Cruiser',       2),
  ('toyota',     'land-cruiser-70',  'لاندكروزر 70 (بكب)',  'Land Cruiser 70',    3),
  ('toyota',     'prado',            'برادو',               'Prado',              4),
  ('toyota',     'fortuner',         'فورتشنر',             'Fortuner',           5),
  ('toyota',     'corolla',          'كورولا',              'Corolla',            6),
  ('toyota',     'camry',            'كامري',               'Camry',              7),
  ('toyota',     'yaris',            'ياريس',               'Yaris',              8),
  ('toyota',     'hiace',            'هايس',                'Hiace',              9),
  ('hyundai',    'accent',           'أكسنت',               'Accent',             1),
  ('hyundai',    'elantra',          'إلنترا',              'Elantra',            2),
  ('hyundai',    'sonata',           'سوناتا',              'Sonata',             3),
  ('hyundai',    'tucson',           'توسان',               'Tucson',             4),
  ('hyundai',    'santa-fe',         'سنتافي',              'Santa Fe',           5),
  ('hyundai',    'atos',             'أتوس',                'Atos',               6),
  ('hyundai',    'i10',              'i10',                 'i10',                7),
  ('hyundai',    'h1',               'H1 (ستاركس)',         'H1 (Starex)',        8),
  ('hyundai',    'porter',           'بورتر (H100)',        'Porter (H100)',      9),
  ('kia',        'picanto',          'بيكانتو',             'Picanto',            1),
  ('kia',        'rio',              'ريو',                 'Rio',                2),
  ('kia',        'cerato',           'سيراتو',              'Cerato',             3),
  ('kia',        'sportage',         'سبورتاج',             'Sportage',           4),
  ('kia',        'sorento',          'سورنتو',              'Sorento',            5),
  ('kia',        'k2700',            'K2700 (بونقو)',       'K2700 (Bongo)',      6),
  ('nissan',     'sunny',            'صني',                 'Sunny',              1),
  ('nissan',     'patrol',           'باترول',              'Patrol',             2),
  ('nissan',     'navara',           'نافارا',              'Navara',             3),
  ('nissan',     'pickup-d22',       'نيسان بكب (D22)',     'Pickup (D22)',       4),
  ('nissan',     'x-trail',          'إكس تريل',            'X-Trail',            5),
  ('nissan',     'urvan',            'أورفان',              'Urvan',              6),
  ('mitsubishi', 'l200',             'L200',                'L200',               1),
  ('mitsubishi', 'pajero',           'باجيرو',              'Pajero',             2),
  ('mitsubishi', 'lancer',           'لانسر',               'Lancer',             3),
  ('isuzu',      'd-max',            'دي ماكس',             'D-Max',              1),
  ('suzuki',     'alto',             'ألتو',                'Alto',               1),
  ('suzuki',     'swift',            'سويفت',               'Swift',              2),
  ('suzuki',     'grand-vitara',     'جراند فيتارا',        'Grand Vitara',       3),
  ('honda',      'civic',            'سيفيك',               'Civic',              1),
  ('honda',      'accord',           'أكورد',               'Accord',             2),
  ('honda',      'cr-v',             'سي آر في',            'CR-V',               3),
  ('mercedes',   'e-class',          'الفئة E',             'E-Class',            1),
  ('mercedes',   'c-class',          'الفئة C',             'C-Class',            2),
  ('ford',       'ranger',           'رينجر',               'Ranger',             1),
  ('geely',      'emgrand',          'إمجراند',             'Emgrand',            1),
  ('chery',      'tiggo-2',          'تيجو 2',              'Tiggo 2',            1),
  ('chery',      'tiggo-7',          'تيجو 7',              'Tiggo 7',            2),
  ('great-wall', 'wingle',           'وينجل',               'Wingle',             1)
) as x(make, slug, ar, en, sort)
join public.vehicle_makes mk on mk.slug = x.make
on conflict (make_id, slug) do nothing;

-- ------------------------------------------------------------------ variants
insert into public.vehicle_variants (model_id, slug, year_from, year_to, engine_ar, engine_en, engine_code, fuel, sort)
select md.id, x.slug, x.y1, x.y2, x.ar, x.en, x.code, x.fuel, x.sort
from (values
  -- Toyota
  ('toyota', 'hilux', '1998-2004-2-4-petrol', 1998, 2004, '2.4 بنزين', '2.4 petrol', '2RZ-FE', 'PETROL', 1),
  ('toyota', 'hilux', '1998-2004-3-0-diesel', 1998, 2004, '3.0 ديزل', '3.0 diesel', '5L', 'DIESEL', 2),
  ('toyota', 'hilux', '2005-2015-2-7-petrol', 2005, 2015, '2.7 بنزين', '2.7 petrol', '2TR-FE', 'PETROL', 3),
  ('toyota', 'hilux', '2005-2015-2-5-diesel', 2005, 2015, '2.5 ديزل', '2.5 diesel', '2KD-FTV', 'DIESEL', 4),
  ('toyota', 'hilux', '2005-2015-3-0-diesel', 2005, 2015, '3.0 ديزل', '3.0 diesel', '1KD-FTV', 'DIESEL', 5),
  ('toyota', 'hilux', '2016-2026-2-7-petrol', 2016, 2026, '2.7 بنزين', '2.7 petrol', '2TR-FE', 'PETROL', 6),
  ('toyota', 'hilux', '2016-2026-2-4-diesel', 2016, 2026, '2.4 ديزل', '2.4 diesel', '2GD-FTV', 'DIESEL', 7),
  ('toyota', 'hilux', '2016-2026-2-8-diesel', 2016, 2026, '2.8 ديزل', '2.8 diesel', '1GD-FTV', 'DIESEL', 8),
  ('toyota', 'land-cruiser', '1998-2007-4-5-petrol', 1998, 2007, '4.5 بنزين', '4.5 petrol', '1FZ-FE', 'PETROL', 1),
  ('toyota', 'land-cruiser', '1998-2007-4-7-petrol-v8', 1998, 2007, '4.7 بنزين V8', '4.7 petrol V8', '2UZ-FE', 'PETROL', 2),
  ('toyota', 'land-cruiser', '2008-2021-4-0-petrol-v6', 2008, 2021, '4.0 بنزين V6', '4.0 petrol V6', '1GR-FE', 'PETROL', 3),
  ('toyota', 'land-cruiser', '2008-2021-4-6-petrol-v8', 2008, 2021, '4.6 بنزين V8', '4.6 petrol V8', '1UR-FE', 'PETROL', 4),
  ('toyota', 'land-cruiser', '2008-2021-5-7-petrol-v8', 2008, 2021, '5.7 بنزين V8', '5.7 petrol V8', '3UR-FE', 'PETROL', 5),
  ('toyota', 'land-cruiser', '2008-2021-4-5-diesel-v8', 2008, 2021, '4.5 ديزل V8', '4.5 diesel V8', '1VD-FTV', 'DIESEL', 6),
  ('toyota', 'land-cruiser', '2022-2026-3-5-petrol-turbo', 2022, 2026, '3.5 بنزين تيربو V6', '3.5 petrol turbo V6', 'V35A-FTS', 'PETROL', 7),
  ('toyota', 'land-cruiser', '2022-2026-3-3-diesel', 2022, 2026, '3.3 ديزل V6', '3.3 diesel V6', 'F33A-FTV', 'DIESEL', 8),
  ('toyota', 'land-cruiser-70', '1990-2023-4-2-diesel', 1990, 2023, '4.2 ديزل', '4.2 diesel', '1HZ', 'DIESEL', 1),
  ('toyota', 'land-cruiser-70', '2007-2026-4-5-diesel-v8', 2007, 2026, '4.5 ديزل V8', '4.5 diesel V8', '1VD-FTV', 'DIESEL', 2),
  ('toyota', 'land-cruiser-70', '2009-2026-4-0-petrol-v6', 2009, 2026, '4.0 بنزين V6', '4.0 petrol V6', '1GR-FE', 'PETROL', 3),
  ('toyota', 'prado', '2003-2009-2-7-petrol', 2003, 2009, '2.7 بنزين', '2.7 petrol', '2TR-FE', 'PETROL', 1),
  ('toyota', 'prado', '2003-2009-4-0-petrol-v6', 2003, 2009, '4.0 بنزين V6', '4.0 petrol V6', '1GR-FE', 'PETROL', 2),
  ('toyota', 'prado', '2010-2023-2-7-petrol', 2010, 2023, '2.7 بنزين', '2.7 petrol', '2TR-FE', 'PETROL', 3),
  ('toyota', 'prado', '2010-2023-4-0-petrol-v6', 2010, 2023, '4.0 بنزين V6', '4.0 petrol V6', '1GR-FE', 'PETROL', 4),
  ('toyota', 'prado', '2015-2023-2-8-diesel', 2015, 2023, '2.8 ديزل', '2.8 diesel', '1GD-FTV', 'DIESEL', 5),
  ('toyota', 'fortuner', '2005-2015-2-7-petrol', 2005, 2015, '2.7 بنزين', '2.7 petrol', '2TR-FE', 'PETROL', 1),
  ('toyota', 'fortuner', '2005-2015-4-0-petrol-v6', 2005, 2015, '4.0 بنزين V6', '4.0 petrol V6', '1GR-FE', 'PETROL', 2),
  ('toyota', 'fortuner', '2016-2026-2-7-petrol', 2016, 2026, '2.7 بنزين', '2.7 petrol', '2TR-FE', 'PETROL', 3),
  ('toyota', 'fortuner', '2016-2026-2-8-diesel', 2016, 2026, '2.8 ديزل', '2.8 diesel', '1GD-FTV', 'DIESEL', 4),
  ('toyota', 'corolla', '2008-2013-1-6-petrol', 2008, 2013, '1.6 بنزين', '1.6 petrol', '1ZR-FE', 'PETROL', 1),
  ('toyota', 'corolla', '2008-2013-1-8-petrol', 2008, 2013, '1.8 بنزين', '1.8 petrol', '2ZR-FE', 'PETROL', 2),
  ('toyota', 'corolla', '2014-2019-1-6-petrol', 2014, 2019, '1.6 بنزين', '1.6 petrol', '1ZR-FE', 'PETROL', 3),
  ('toyota', 'corolla', '2014-2019-1-8-petrol', 2014, 2019, '1.8 بنزين', '1.8 petrol', '2ZR-FE', 'PETROL', 4),
  ('toyota', 'corolla', '2020-2026-1-6-petrol', 2020, 2026, '1.6 بنزين', '1.6 petrol', '1ZR-FE', 'PETROL', 5),
  ('toyota', 'corolla', '2020-2026-2-0-petrol', 2020, 2026, '2.0 بنزين', '2.0 petrol', 'M20A-FKS', 'PETROL', 6),
  ('toyota', 'camry', '2012-2017-2-5-petrol', 2012, 2017, '2.5 بنزين', '2.5 petrol', '2AR-FE', 'PETROL', 1),
  ('toyota', 'camry', '2018-2024-2-5-petrol', 2018, 2024, '2.5 بنزين', '2.5 petrol', 'A25A-FKS', 'PETROL', 2),
  ('toyota', 'yaris', '2006-2013-1-3-petrol', 2006, 2013, '1.3 بنزين', '1.3 petrol', '2NZ-FE', 'PETROL', 1),
  ('toyota', 'yaris', '2014-2020-1-5-petrol', 2014, 2020, '1.5 بنزين', '1.5 petrol', '2NR-FE', 'PETROL', 2),
  ('toyota', 'hiace', '2005-2018-2-7-petrol', 2005, 2018, '2.7 بنزين', '2.7 petrol', '2TR-FE', 'PETROL', 1),
  ('toyota', 'hiace', '2005-2018-2-5-diesel', 2005, 2018, '2.5 ديزل', '2.5 diesel', '2KD-FTV', 'DIESEL', 2),
  ('toyota', 'hiace', '2019-2026-3-5-petrol-v6', 2019, 2026, '3.5 بنزين V6', '3.5 petrol V6', '7GR-FKS', 'PETROL', 3),
  ('toyota', 'hiace', '2019-2026-2-8-diesel', 2019, 2026, '2.8 ديزل', '2.8 diesel', '1GD-FTV', 'DIESEL', 4),
  -- Hyundai
  ('hyundai', 'accent', '2006-2010-1-6-petrol', 2006, 2010, '1.6 بنزين', '1.6 petrol', null, 'PETROL', 1),
  ('hyundai', 'accent', '2011-2017-1-4-petrol', 2011, 2017, '1.4 بنزين', '1.4 petrol', null, 'PETROL', 2),
  ('hyundai', 'accent', '2011-2017-1-6-petrol', 2011, 2017, '1.6 بنزين', '1.6 petrol', null, 'PETROL', 3),
  ('hyundai', 'accent', '2018-2023-1-4-petrol', 2018, 2023, '1.4 بنزين', '1.4 petrol', null, 'PETROL', 4),
  ('hyundai', 'accent', '2018-2023-1-6-petrol', 2018, 2023, '1.6 بنزين', '1.6 petrol', null, 'PETROL', 5),
  ('hyundai', 'elantra', '2011-2015-1-8-petrol', 2011, 2015, '1.8 بنزين', '1.8 petrol', null, 'PETROL', 1),
  ('hyundai', 'elantra', '2016-2020-1-6-petrol', 2016, 2020, '1.6 بنزين', '1.6 petrol', null, 'PETROL', 2),
  ('hyundai', 'elantra', '2016-2020-2-0-petrol', 2016, 2020, '2.0 بنزين', '2.0 petrol', null, 'PETROL', 3),
  ('hyundai', 'elantra', '2021-2026-1-6-petrol', 2021, 2026, '1.6 بنزين', '1.6 petrol', null, 'PETROL', 4),
  ('hyundai', 'elantra', '2021-2026-2-0-petrol', 2021, 2026, '2.0 بنزين', '2.0 petrol', null, 'PETROL', 5),
  ('hyundai', 'sonata', '2011-2014-2-4-petrol', 2011, 2014, '2.4 بنزين', '2.4 petrol', null, 'PETROL', 1),
  ('hyundai', 'sonata', '2015-2019-2-4-petrol', 2015, 2019, '2.4 بنزين', '2.4 petrol', null, 'PETROL', 2),
  ('hyundai', 'sonata', '2020-2026-2-5-petrol', 2020, 2026, '2.5 بنزين', '2.5 petrol', null, 'PETROL', 3),
  ('hyundai', 'tucson', '2010-2015-2-0-petrol', 2010, 2015, '2.0 بنزين', '2.0 petrol', null, 'PETROL', 1),
  ('hyundai', 'tucson', '2010-2015-2-4-petrol', 2010, 2015, '2.4 بنزين', '2.4 petrol', null, 'PETROL', 2),
  ('hyundai', 'tucson', '2016-2021-2-0-petrol', 2016, 2021, '2.0 بنزين', '2.0 petrol', null, 'PETROL', 3),
  ('hyundai', 'tucson', '2016-2021-2-4-petrol', 2016, 2021, '2.4 بنزين', '2.4 petrol', null, 'PETROL', 4),
  ('hyundai', 'tucson', '2022-2026-2-0-petrol', 2022, 2026, '2.0 بنزين', '2.0 petrol', null, 'PETROL', 5),
  ('hyundai', 'tucson', '2022-2026-2-5-petrol', 2022, 2026, '2.5 بنزين', '2.5 petrol', null, 'PETROL', 6),
  ('hyundai', 'santa-fe', '2013-2018-2-4-petrol', 2013, 2018, '2.4 بنزين', '2.4 petrol', null, 'PETROL', 1),
  ('hyundai', 'santa-fe', '2013-2018-3-3-petrol-v6', 2013, 2018, '3.3 بنزين V6', '3.3 petrol V6', null, 'PETROL', 2),
  ('hyundai', 'santa-fe', '2019-2023-2-4-petrol', 2019, 2023, '2.4 بنزين', '2.4 petrol', null, 'PETROL', 3),
  ('hyundai', 'santa-fe', '2019-2023-3-5-petrol-v6', 2019, 2023, '3.5 بنزين V6', '3.5 petrol V6', null, 'PETROL', 4),
  ('hyundai', 'atos', '1998-2014-1-1-petrol', 1998, 2014, '1.1 بنزين', '1.1 petrol', null, 'PETROL', 1),
  ('hyundai', 'i10', '2008-2013-1-1-petrol', 2008, 2013, '1.1 بنزين', '1.1 petrol', null, 'PETROL', 1),
  ('hyundai', 'i10', '2014-2019-1-2-petrol', 2014, 2019, '1.2 بنزين', '1.2 petrol', null, 'PETROL', 2),
  ('hyundai', 'h1', '2008-2021-2-4-petrol', 2008, 2021, '2.4 بنزين', '2.4 petrol', null, 'PETROL', 1),
  ('hyundai', 'h1', '2008-2021-2-5-diesel', 2008, 2021, '2.5 ديزل', '2.5 diesel', null, 'DIESEL', 2),
  ('hyundai', 'porter', '2004-2026-2-5-diesel', 2004, 2026, '2.5 ديزل', '2.5 diesel', null, 'DIESEL', 1),
  -- Kia
  ('kia', 'picanto', '2011-2017-1-2-petrol', 2011, 2017, '1.2 بنزين', '1.2 petrol', null, 'PETROL', 1),
  ('kia', 'picanto', '2018-2026-1-2-petrol', 2018, 2026, '1.2 بنزين', '1.2 petrol', null, 'PETROL', 2),
  ('kia', 'rio', '2012-2017-1-4-petrol', 2012, 2017, '1.4 بنزين', '1.4 petrol', null, 'PETROL', 1),
  ('kia', 'rio', '2012-2017-1-6-petrol', 2012, 2017, '1.6 بنزين', '1.6 petrol', null, 'PETROL', 2),
  ('kia', 'rio', '2018-2023-1-4-petrol', 2018, 2023, '1.4 بنزين', '1.4 petrol', null, 'PETROL', 3),
  ('kia', 'rio', '2018-2023-1-6-petrol', 2018, 2023, '1.6 بنزين', '1.6 petrol', null, 'PETROL', 4),
  ('kia', 'cerato', '2009-2013-1-6-petrol', 2009, 2013, '1.6 بنزين', '1.6 petrol', null, 'PETROL', 1),
  ('kia', 'cerato', '2009-2013-2-0-petrol', 2009, 2013, '2.0 بنزين', '2.0 petrol', null, 'PETROL', 2),
  ('kia', 'cerato', '2014-2018-1-6-petrol', 2014, 2018, '1.6 بنزين', '1.6 petrol', null, 'PETROL', 3),
  ('kia', 'cerato', '2014-2018-2-0-petrol', 2014, 2018, '2.0 بنزين', '2.0 petrol', null, 'PETROL', 4),
  ('kia', 'cerato', '2019-2024-1-6-petrol', 2019, 2024, '1.6 بنزين', '1.6 petrol', null, 'PETROL', 5),
  ('kia', 'cerato', '2019-2024-2-0-petrol', 2019, 2024, '2.0 بنزين', '2.0 petrol', null, 'PETROL', 6),
  ('kia', 'sportage', '2011-2015-2-0-petrol', 2011, 2015, '2.0 بنزين', '2.0 petrol', null, 'PETROL', 1),
  ('kia', 'sportage', '2011-2015-2-4-petrol', 2011, 2015, '2.4 بنزين', '2.4 petrol', null, 'PETROL', 2),
  ('kia', 'sportage', '2016-2021-2-0-petrol', 2016, 2021, '2.0 بنزين', '2.0 petrol', null, 'PETROL', 3),
  ('kia', 'sportage', '2016-2021-2-4-petrol', 2016, 2021, '2.4 بنزين', '2.4 petrol', null, 'PETROL', 4),
  ('kia', 'sportage', '2022-2026-2-0-petrol', 2022, 2026, '2.0 بنزين', '2.0 petrol', null, 'PETROL', 5),
  ('kia', 'sportage', '2022-2026-1-6-petrol-turbo', 2022, 2026, '1.6 بنزين تيربو', '1.6 petrol turbo', null, 'PETROL', 6),
  ('kia', 'sorento', '2015-2020-2-4-petrol', 2015, 2020, '2.4 بنزين', '2.4 petrol', null, 'PETROL', 1),
  ('kia', 'sorento', '2015-2020-3-3-petrol-v6', 2015, 2020, '3.3 بنزين V6', '3.3 petrol V6', null, 'PETROL', 2),
  ('kia', 'k2700', '2004-2026-2-7-diesel', 2004, 2026, '2.7 ديزل', '2.7 diesel', null, 'DIESEL', 1),
  -- Nissan
  ('nissan', 'sunny', '2012-2019-1-5-petrol', 2012, 2019, '1.5 بنزين', '1.5 petrol', 'HR15DE', 'PETROL', 1),
  ('nissan', 'sunny', '2020-2026-1-6-petrol', 2020, 2026, '1.6 بنزين', '1.6 petrol', 'HR16DE', 'PETROL', 2),
  ('nissan', 'patrol', '1998-2010-4-8-petrol', 1998, 2010, '4.8 بنزين', '4.8 petrol', 'TB48DE', 'PETROL', 1),
  ('nissan', 'patrol', '1998-2010-4-2-diesel', 1998, 2010, '4.2 ديزل', '4.2 diesel', 'TD42', 'DIESEL', 2),
  ('nissan', 'patrol', '2010-2026-4-0-petrol-v6', 2010, 2026, '4.0 بنزين V6', '4.0 petrol V6', 'VQ40DE', 'PETROL', 3),
  ('nissan', 'patrol', '2010-2026-5-6-petrol-v8', 2010, 2026, '5.6 بنزين V8', '5.6 petrol V8', 'VK56VD', 'PETROL', 4),
  ('nissan', 'navara', '2005-2015-2-5-diesel', 2005, 2015, '2.5 ديزل', '2.5 diesel', 'YD25DDTi', 'DIESEL', 1),
  ('nissan', 'navara', '2015-2026-2-5-diesel', 2015, 2026, '2.5 ديزل', '2.5 diesel', 'YD25DDTi', 'DIESEL', 2),
  ('nissan', 'navara', '2015-2026-2-5-petrol', 2015, 2026, '2.5 بنزين', '2.5 petrol', 'QR25DE', 'PETROL', 3),
  ('nissan', 'pickup-d22', '1998-2015-2-4-petrol', 1998, 2015, '2.4 بنزين', '2.4 petrol', 'KA24DE', 'PETROL', 1),
  ('nissan', 'pickup-d22', '1998-2015-2-5-diesel', 1998, 2015, '2.5 ديزل', '2.5 diesel', null, 'DIESEL', 2),
  ('nissan', 'x-trail', '2014-2021-2-5-petrol', 2014, 2021, '2.5 بنزين', '2.5 petrol', 'QR25DE', 'PETROL', 1),
  ('nissan', 'urvan', '2001-2012-2-4-petrol', 2001, 2012, '2.4 بنزين', '2.4 petrol', 'KA24DE', 'PETROL', 1),
  ('nissan', 'urvan', '2001-2012-3-0-diesel', 2001, 2012, '3.0 ديزل', '3.0 diesel', 'ZD30', 'DIESEL', 2),
  ('nissan', 'urvan', '2013-2026-2-5-petrol', 2013, 2026, '2.5 بنزين', '2.5 petrol', 'QR25DE', 'PETROL', 3),
  ('nissan', 'urvan', '2013-2026-2-5-diesel', 2013, 2026, '2.5 ديزل', '2.5 diesel', 'YD25DDTi', 'DIESEL', 4),
  -- Mitsubishi
  ('mitsubishi', 'l200', '2006-2015-2-4-petrol', 2006, 2015, '2.4 بنزين', '2.4 petrol', '4G64', 'PETROL', 1),
  ('mitsubishi', 'l200', '2006-2015-2-5-diesel', 2006, 2015, '2.5 ديزل', '2.5 diesel', '4D56', 'DIESEL', 2),
  ('mitsubishi', 'l200', '2015-2024-2-4-petrol', 2015, 2024, '2.4 بنزين', '2.4 petrol', null, 'PETROL', 3),
  ('mitsubishi', 'l200', '2015-2024-2-4-diesel', 2015, 2024, '2.4 ديزل', '2.4 diesel', '4N15', 'DIESEL', 4),
  ('mitsubishi', 'pajero', '2006-2021-3-0-petrol-v6', 2006, 2021, '3.0 بنزين V6', '3.0 petrol V6', '6G72', 'PETROL', 1),
  ('mitsubishi', 'pajero', '2006-2021-3-8-petrol-v6', 2006, 2021, '3.8 بنزين V6', '3.8 petrol V6', '6G75', 'PETROL', 2),
  ('mitsubishi', 'pajero', '2006-2021-3-2-diesel', 2006, 2021, '3.2 ديزل', '3.2 diesel', '4M41', 'DIESEL', 3),
  ('mitsubishi', 'lancer', '2007-2017-1-6-petrol', 2007, 2017, '1.6 بنزين', '1.6 petrol', null, 'PETROL', 1),
  ('mitsubishi', 'lancer', '2007-2017-2-0-petrol', 2007, 2017, '2.0 بنزين', '2.0 petrol', null, 'PETROL', 2),
  -- Isuzu
  ('isuzu', 'd-max', '2012-2019-2-5-diesel', 2012, 2019, '2.5 ديزل', '2.5 diesel', '4JK1', 'DIESEL', 1),
  ('isuzu', 'd-max', '2012-2019-3-0-diesel', 2012, 2019, '3.0 ديزل', '3.0 diesel', '4JJ1', 'DIESEL', 2),
  ('isuzu', 'd-max', '2020-2026-3-0-diesel', 2020, 2026, '3.0 ديزل', '3.0 diesel', '4JJ3', 'DIESEL', 3),
  -- Suzuki
  ('suzuki', 'alto', '2009-2023-1-0-petrol', 2009, 2023, '1.0 بنزين', '1.0 petrol', 'K10B', 'PETROL', 1),
  ('suzuki', 'swift', '2011-2017-1-4-petrol', 2011, 2017, '1.4 بنزين', '1.4 petrol', null, 'PETROL', 1),
  ('suzuki', 'swift', '2018-2024-1-2-petrol', 2018, 2024, '1.2 بنزين', '1.2 petrol', null, 'PETROL', 2),
  ('suzuki', 'grand-vitara', '2006-2015-2-0-petrol', 2006, 2015, '2.0 بنزين', '2.0 petrol', 'J20A', 'PETROL', 1),
  ('suzuki', 'grand-vitara', '2006-2015-2-4-petrol', 2006, 2015, '2.4 بنزين', '2.4 petrol', 'J24B', 'PETROL', 2),
  -- Honda
  ('honda', 'civic', '2012-2015-1-8-petrol', 2012, 2015, '1.8 بنزين', '1.8 petrol', 'R18', 'PETROL', 1),
  ('honda', 'civic', '2016-2021-1-6-petrol', 2016, 2021, '1.6 بنزين', '1.6 petrol', null, 'PETROL', 2),
  ('honda', 'civic', '2016-2021-2-0-petrol', 2016, 2021, '2.0 بنزين', '2.0 petrol', null, 'PETROL', 3),
  ('honda', 'accord', '2013-2017-2-4-petrol', 2013, 2017, '2.4 بنزين', '2.4 petrol', 'K24', 'PETROL', 1),
  ('honda', 'cr-v', '2012-2016-2-4-petrol', 2012, 2016, '2.4 بنزين', '2.4 petrol', 'K24', 'PETROL', 1),
  ('honda', 'cr-v', '2017-2022-2-4-petrol', 2017, 2022, '2.4 بنزين', '2.4 petrol', 'K24', 'PETROL', 2),
  -- Mercedes-Benz (by body generation)
  ('mercedes', 'e-class', '1985-1997-w124-petrol', 1985, 1997, 'W124 · بنزين', 'W124 · petrol', 'W124', 'PETROL', 1),
  ('mercedes', 'e-class', '1995-2002-w210-petrol', 1995, 2002, 'W210 · بنزين', 'W210 · petrol', 'W210', 'PETROL', 2),
  ('mercedes', 'e-class', '2002-2009-w211-petrol', 2002, 2009, 'W211 · بنزين', 'W211 · petrol', 'W211', 'PETROL', 3),
  ('mercedes', 'e-class', '2009-2016-w212-petrol', 2009, 2016, 'W212 · بنزين', 'W212 · petrol', 'W212', 'PETROL', 4),
  ('mercedes', 'c-class', '1993-2000-w202-petrol', 1993, 2000, 'W202 · بنزين', 'W202 · petrol', 'W202', 'PETROL', 1),
  ('mercedes', 'c-class', '2000-2007-w203-petrol', 2000, 2007, 'W203 · بنزين', 'W203 · petrol', 'W203', 'PETROL', 2),
  ('mercedes', 'c-class', '2007-2014-w204-petrol', 2007, 2014, 'W204 · بنزين', 'W204 · petrol', 'W204', 'PETROL', 3),
  -- Ford
  ('ford', 'ranger', '2012-2022-2-2-diesel', 2012, 2022, '2.2 ديزل', '2.2 diesel', null, 'DIESEL', 1),
  ('ford', 'ranger', '2012-2022-3-2-diesel', 2012, 2022, '3.2 ديزل', '3.2 diesel', null, 'DIESEL', 2),
  -- Chinese makes
  ('geely', 'emgrand', '2009-2018-1-5-petrol', 2009, 2018, '1.5 بنزين', '1.5 petrol', null, 'PETROL', 1),
  ('geely', 'emgrand', '2009-2018-1-8-petrol', 2009, 2018, '1.8 بنزين', '1.8 petrol', null, 'PETROL', 2),
  ('geely', 'emgrand', '2019-2026-1-5-petrol', 2019, 2026, '1.5 بنزين', '1.5 petrol', null, 'PETROL', 3),
  ('chery', 'tiggo-2', '2017-2026-1-5-petrol', 2017, 2026, '1.5 بنزين', '1.5 petrol', null, 'PETROL', 1),
  ('chery', 'tiggo-7', '2019-2026-1-5-petrol-turbo', 2019, 2026, '1.5 بنزين تيربو', '1.5 petrol turbo', null, 'PETROL', 1),
  ('great-wall', 'wingle', '2010-2026-2-0-diesel', 2010, 2026, '2.0 ديزل', '2.0 diesel', null, 'DIESEL', 1),
  ('great-wall', 'wingle', '2010-2026-2-2-petrol', 2010, 2026, '2.2 بنزين', '2.2 petrol', null, 'PETROL', 2)
) as x(make, model, slug, y1, y2, ar, en, code, fuel, sort)
join public.vehicle_makes mk on mk.slug = x.make
join public.vehicle_models md on md.make_id = mk.id and md.slug = x.model
on conflict (model_id, slug) do nothing;

-- ------------------------------------------------------------------ starter parts
-- Only inserted when the category has no parts yet, so a re-run never duplicates them.
insert into public.parts (category_id, name_ar, name_en, installable, std_job_minutes, keywords)
select c.id, x.ar, x.en, x.inst, x.minutes, x.kw
from (values
  ('lighting', 'لمبة أمامية H4', 'H4 headlight bulb', true, null, array['كشاف', 'لمبة قدام', 'headlight']),
  ('lighting', 'لمبة أمامية H7', 'H7 headlight bulb', true, null, array['كشاف', 'headlight']),
  ('lighting', 'لمبة H11', 'H11 bulb', true, null, array['ضباب', 'fog']),
  ('lighting', 'لمبات LED أمامية (زوج)', 'LED headlight bulbs (pair)', true, null, array['ليد', 'كشاف', 'headlight']),
  ('lighting', 'فانوس أمامي', 'Headlamp assembly', true, 60, array['شمعة', 'كشاف', 'headlamp']),
  ('lighting', 'فانوس خلفي (سطب)', 'Tail lamp', true, null, array['سطب', 'اسطب', 'tail light']),
  ('lighting', 'لمبة إشارة', 'Indicator bulb', true, 15, array['اشارة', 'سيقنال', 'indicator']),
  ('lighting', 'لمبة فرامل خلفية', 'Brake light bulb', true, 15, array['سطب', 'stop']),
  ('lighting', 'كشافات ضباب', 'Fog lamps', true, 60, array['ضباب', 'fog']),
  ('brakes', 'فحمات فرامل أمامية', 'Front brake pads', true, null, array['تيل', 'بريك', 'pads']),
  ('brakes', 'فحمات فرامل خلفية', 'Rear brake pads', true, null, array['تيل', 'بريك', 'pads']),
  ('brakes', 'أقراص فرامل أمامية (ديسك)', 'Front brake discs', true, 90, array['ديسك', 'هوب', 'disc', 'rotor']),
  ('brakes', 'تيل فرامل خلفي (طنابير)', 'Rear brake shoes', true, null, array['طنبور', 'drum', 'shoes']),
  ('brakes', 'سلندر فرامل', 'Brake cylinder', true, null, array['ماستر', 'cylinder']),
  ('brakes', 'زيت فرامل DOT4', 'DOT4 brake fluid', false, null, array['زيت بريك', 'brake fluid']),
  ('oil-filters', 'زيت محرك 5W-30', '5W-30 engine oil', true, null, array['تغيير زيت', 'زيت مكينة']),
  ('oil-filters', 'زيت محرك 10W-40', '10W-40 engine oil', true, null, array['تغيير زيت', 'زيت مكينة']),
  ('oil-filters', 'زيت محرك 20W-50', '20W-50 engine oil', true, null, array['تغيير زيت', 'زيت مكينة']),
  ('oil-filters', 'زيت ديزل 15W-40', '15W-40 diesel engine oil', true, null, array['تغيير زيت', 'جاز']),
  ('oil-filters', 'فلتر زيت', 'Oil filter', true, 15, array['فلتر مكينة']),
  ('oil-filters', 'فلتر هواء', 'Air filter', true, 15, array['فلتر مكينة']),
  ('oil-filters', 'فلتر وقود', 'Fuel filter', true, 30, array['فلتر جاز', 'فلتر بنزين', 'فلتر ديزل']),
  ('oil-filters', 'زيت قير أوتوماتيك (ATF)', 'Automatic transmission fluid (ATF)', true, 45, array['زيت جير', 'اوتوماتيك']),
  ('oil-filters', 'زيت قير عادي', 'Manual gearbox oil', true, null, array['زيت جير', 'زيت دفرنس']),
  ('oil-filters', 'ماء رديتر (كولانت)', 'Coolant', true, 20, array['مويه رديتر', 'كولنت']),
  ('batteries', 'بطارية 55 أمبير', '55 Ah battery', true, null, array['بطاريه']),
  ('batteries', 'بطارية 70 أمبير', '70 Ah battery', true, null, array['بطاريه']),
  ('batteries', 'بطارية 100 أمبير', '100 Ah battery', true, null, array['بطاريه']),
  ('electrical', 'دينمو (مولد الشحن)', 'Alternator', true, 120, array['دينامو', 'مولد']),
  ('electrical', 'مارش (سلف)', 'Starter motor', true, 90, array['سلف', 'starter']),
  ('electrical', 'بوري', 'Horn', true, 30, array['زمارة', 'كلاكس']),
  ('electrical', 'حساس أكسجين', 'Oxygen sensor', true, 45, array['حساس', 'سنسر', 'o2']),
  ('electrical', 'حساس حرارة', 'Temperature sensor', true, 30, array['حساس', 'سنسر']),
  ('electrical', 'كويل (بوبينة)', 'Ignition coil', true, 30, array['بوبينة', 'coil']),
  ('electrical', 'ريلاي', 'Relay', true, 15, array['relay']),
  ('electrical', 'فيوزات (طقم)', 'Fuse set', false, null, array['فيوز', 'fuse']),
  ('electrical', 'كاميرا خلفية', 'Reversing camera', true, 60, array['كاميرا', 'camera']),
  ('electrical', 'شاشة سيارة', 'Car stereo screen', true, 90, array['مسجل', 'راديو', 'stereo']),
  ('ac', 'تعبئة غاز المكيف', 'AC gas refill', true, 45, array['فريون', 'شحن مكيف']),
  ('ac', 'كمبروسر المكيف', 'AC compressor', true, 150, array['كمبروسر']),
  ('ac', 'كوندنسر المكيف', 'AC condenser', true, 120, array['رديتر مكيف', 'condenser']),
  ('ac', 'فلتر المكيف (الكابينة)', 'Cabin air filter', true, 15, array['فلتر مكيف']),
  ('ac', 'مروحة المكيف (بلور)', 'AC blower motor', true, 60, array['بلور', 'blower']),
  ('suspension', 'مساعدات أمامية (زوج)', 'Front shock absorbers (pair)', true, null, array['امتصاص', 'shocks']),
  ('suspension', 'مساعدات خلفية (زوج)', 'Rear shock absorbers (pair)', true, 60, array['امتصاص', 'shocks']),
  ('suspension', 'مقص أمامي سفلي', 'Front lower control arm', true, null, array['مقص', 'arm']),
  ('suspension', 'بلف (مفصل كروي)', 'Ball joint', true, 60, array['مفصل', 'ball joint']),
  ('suspension', 'مسمار دركسون', 'Tie rod end', true, 45, array['دركسون', 'tie rod']),
  ('suspension', 'جلب عفشة', 'Suspension bushings', true, null, array['جلبة', 'بوشات', 'bush']),
  ('suspension', 'بلي عجل', 'Wheel bearing', true, null, array['رمان بلي', 'bearing']),
  ('tyres', 'إطار 185/65R15', 'Tyre 185/65 R15', true, null, array['لستك', 'كفر']),
  ('tyres', 'إطار 205/55R16', 'Tyre 205/55 R16', true, null, array['لستك', 'كفر']),
  ('tyres', 'إطار 265/65R17', 'Tyre 265/65 R17', true, null, array['لستك', 'كفر']),
  ('tyres', 'إطار 265/70R16', 'Tyre 265/70 R16', true, null, array['لستك', 'كفر']),
  ('tyres', 'جنط', 'Wheel rim', true, null, array['رنق', 'rim']),
  ('engine', 'بواجي (طقم)', 'Spark plugs (set)', true, 30, array['بوجي', 'بلك']),
  ('engine', 'سير المحرك', 'Drive belt', true, 45, array['سير', 'belt']),
  ('engine', 'سير التايمن', 'Timing belt', true, 180, array['تايمن', 'timing']),
  ('engine', 'طلمبة ماء', 'Water pump', true, 120, array['طرمبة', 'مضخة']),
  ('engine', 'رديتر', 'Radiator', true, 120, array['ردياتير']),
  ('engine', 'ثرموستات', 'Thermostat', true, 60, array['ترموستات']),
  ('engine', 'طلمبة بنزين', 'Fuel pump', true, null, array['طرمبة', 'مضخة']),
  ('engine', 'جوان وش السلندر', 'Head gasket', true, 300, array['جوان', 'gasket']),
  ('engine', 'كراسي المكينة', 'Engine mounts', true, null, array['كرسي مكينة', 'mount']),
  ('transmission', 'طقم كلتش', 'Clutch kit', true, 240, array['دبرياج', 'clutch']),
  ('transmission', 'عكس (عمود الدوران)', 'CV axle', true, 90, array['عمود', 'axle']),
  ('transmission', 'فلتر قير أوتوماتيك', 'Automatic transmission filter', true, 60, array['فلتر جير']),
  ('body', 'مراية جانبية', 'Side mirror', false, null, array['مراية', 'مرايه', 'mirror']),
  ('body', 'مساحات (زوج)', 'Wiper blades (pair)', false, null, array['مساحة', 'wiper']),
  ('body', 'زجاج أمامي', 'Windscreen', false, null, array['قزاز', 'glass']),
  ('body', 'صدام أمامي', 'Front bumper', false, null, array['اكصدام', 'bumper']),
  ('accessories', 'كسوة مقاعد', 'Seat covers', false, null, array['تلبيسة']),
  ('accessories', 'دواسات أرضية', 'Floor mats', false, null, array['فرش', 'mats']),
  ('accessories', 'حامل جوال', 'Phone holder', false, null, array['حامل موبايل']),
  ('accessories', 'شاحن سيارة', 'Car charger', false, null, array['شاحن موبايل']),
  ('accessories', 'معطر سيارة', 'Car air freshener', false, null, array['ريحة'])
) as x(cat, ar, en, inst, minutes, kw)
join public.part_categories c on c.slug = x.cat
where not exists (select 1 from public.parts p where p.category_id = c.id);

-- ------------------------------------------------------------------ synonyms
insert into public.search_synonyms (terms)
select x.terms
from (values
  (array['لمبة', 'لمبات', 'بلب', 'ضو', 'نور', 'bulb', 'bulbs', 'lamp']),
  (array['كشاف', 'كشافات', 'فانوس', 'headlight', 'headlamp']),
  (array['فحمات', 'فحمة', 'تيل', 'pads', 'pad']),
  (array['فرامل', 'بريك', 'brake', 'brakes']),
  (array['ديسك', 'ديسكات', 'اقراص', 'قرص', 'disc', 'rotor']),
  (array['زيت', 'زيوت', 'oil']),
  (array['فلتر', 'فلاتر', 'filter']),
  (array['بطارية', 'بطاريات', 'battery', 'batteries']),
  (array['اطار', 'اطارات', 'لستك', 'لساتك', 'كفر', 'tyre', 'tyres', 'tire', 'tires']),
  (array['جنط', 'جنوط', 'رنق', 'rim', 'wheel']),
  (array['مساعد', 'مساعدات', 'امتصاص', 'shock', 'shocks', 'absorber']),
  (array['مقص', 'مقصات', 'arm']),
  (array['بوجي', 'بواجي', 'بلك', 'spark', 'plug', 'plugs']),
  (array['مكيف', 'تكييف', 'كندشن', 'ac', 'aircon']),
  (array['كمبروسر', 'compressor']),
  (array['فريون', 'غاز', 'gas', 'refrigerant']),
  (array['بوري', 'زمارة', 'كلاكس', 'horn']),
  (array['دينمو', 'دينامو', 'مولد', 'alternator']),
  (array['مارش', 'سلف', 'starter']),
  (array['سير', 'سيور', 'belt']),
  (array['رديتر', 'ردياتير', 'radiator']),
  (array['طلمبة', 'طرمبة', 'مضخة', 'pump']),
  (array['كلتش', 'دبرياج', 'clutch']),
  (array['قير', 'جير', 'gear', 'gearbox', 'transmission']),
  (array['مساحة', 'مساحات', 'wiper', 'wipers']),
  (array['مراية', 'مرايه', 'مراة', 'mirror']),
  (array['صدام', 'اكصدام', 'bumper']),
  (array['حساس', 'حساسات', 'سنسر', 'sensor']),
  (array['فيوز', 'فيوزات', 'fuse']),
  (array['بلي', 'رمان', 'bearing']),
  (array['جوان', 'جوانات', 'gasket']),
  (array['كسوة', 'تلبيسة', 'covers']),
  (array['ماء', 'مويه', 'كولانت', 'coolant']),
  (array['هايلكس', 'هيلوكس', 'hilux']),
  (array['لاندكروزر', 'لاند كروزر', 'شاص', 'land', 'cruiser']),
  (array['تويوتا', 'toyota']),
  (array['هيونداي', 'هونداي', 'hyundai'])
) as x(terms)
where not exists (select 1 from public.search_synonyms);

-- ------------------------------------------------------------------ market and street
insert into public.markets (slug, name_ar, name_en) values
  ('alghali', 'سوق شارع الغالي', 'Alghali Street market')
on conflict (slug) do nothing;

insert into public.streets (market_id, slug, name_ar, name_en, length_m)
select m.id, 'alghali', 'شارع الغالي', 'Alghali Street', 1200
from public.markets m where m.slug = 'alghali'
on conflict (market_id, slug) do nothing;

insert into public.zones (street_id, seq, name_ar, name_en, from_m, to_m)
select s.id, x.seq, x.ar, x.en, x.f, x.t
from (values
  (1, 'القطاع 1', 'Section 1',   0,  300),
  (2, 'القطاع 2', 'Section 2', 300,  600),
  (3, 'القطاع 3', 'Section 3', 600,  900),
  (4, 'القطاع 4', 'Section 4', 900, 1200)
) as x(seq, ar, en, f, t)
cross join public.streets s
where s.slug = 'alghali'
on conflict (street_id, seq) do nothing;
