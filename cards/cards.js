(() => {
  'use strict';
  const main = document.querySelector('main[data-catalog]');
  if (!main) return;
  const search = document.querySelector('#card-search');
  const league = document.querySelector('#card-league');
  const team = document.querySelector('#card-team');
  const grid = document.querySelector('#card-grid');
  const result = document.querySelector('#card-result');
  const message = document.querySelector('#catalog-message');
  const retry = document.querySelector('#retry-catalog');
  const previous = document.querySelector('#previous-page');
  const next = document.querySelector('#next-page');
  const dialog = document.querySelector('.card-detail');
  const kinds = {player:'球員',coach:'教練',cheer:'啦啦隊／應援'};
  const rarities = {cyan:'灰',green:'綠',blue:'藍',red:'紅',purple:'紫',gold:'金',diamond:'鑽石'};
  const params = new URLSearchParams(location.search);
  let kind = Object.hasOwn(kinds,params.get('type')) ? params.get('type') : 'player';
  let page = Math.max(0,Math.min(1000,(parseInt(params.get('page'),10)||1)-1));
  let cards = [], filtered = [], detailIndex = 0, returnFocus = null;
  const pageSize = 24;
  let loadNumber = 0;
  search.value = (params.get('q')||'').slice(0,100);

  const text = (tag, value, className) => {
    const node = document.createElement(tag);
    node.textContent = value;
    if (className) node.className = className;
    return node;
  };
  const safeImage = value => typeof value==='string' && /^\/assets\/card-preview\/(?:full|thumb)\/[a-f0-9]{20}\.webp$/.test(value);
  function updateAddress() {
    const p = new URLSearchParams();
    if (kind!=='player') p.set('type',kind);
    if (search.value.trim()) p.set('q',search.value.trim());
    if (league.value) p.set('league',league.value);
    if (team.value) p.set('team',team.value);
    if (page) p.set('page',String(page+1));
    history.replaceState(null,'',location.pathname+(p.size?'?'+p.toString():''));
  }
  function populateFilters() {
    const leagues = [...new Set(cards.map(c=>c.league))];
    const teams = [...new Set(cards.map(c=>c.team))];
    for (const value of leagues) league.add(new Option(value,value));
    for (const value of teams) team.add(new Option(value,value));
    league.value = leagues.includes(params.get('league')) ? params.get('league') : '';
    team.value = teams.includes(params.get('team')) ? params.get('team') : '';
  }
  function render() {
    const query = search.value.trim().toLocaleLowerCase();
    filtered = cards.filter(card=>card.kind===kind&&(!league.value||card.league===league.value)&&(!team.value||card.team===team.value)&&(!query||[card.name,card.team,card.position,card.specialty].join(' ').toLocaleLowerCase().includes(query)));
    const pages = Math.max(1,Math.ceil(filtered.length/pageSize));
    page = Math.max(0,Math.min(page,pages-1));
    document.querySelectorAll('[data-kind]').forEach(button=>button.setAttribute('aria-pressed',String(button.dataset.kind===kind)));
    result.textContent = `${kinds[kind]} · ${filtered.length} 張${league.value||team.value||query?'符合篩選':''}`;
    const fragment = document.createDocumentFragment();
    for (const [offset,card] of filtered.slice(page*pageSize,(page+1)*pageSize).entries()) {
      const button = document.createElement('button');
      button.type='button'; button.className='catalog-card';
      button.setAttribute('aria-label',`查看${kinds[kind]} ${card.name}・${card.team}`);
      const image = document.createElement('img');
      image.src=card.thumbnail; image.alt=`${card.name}・${card.team} ${kinds[kind]}卡面`;
      image.width=256; image.height=384; image.loading='lazy'; image.decoding='async'; image.className='card-image';
      button.append(image,text('span',card.name,'card-name'));
      const club = text('span',card.team,'card-club');
      if (card.position) club.prepend(text('span',card.position,'card-position'));
      button.append(club);
      button.addEventListener('click',()=>{returnFocus=button;showDetail(page*pageSize+offset);});
      fragment.append(button);
    }
    grid.replaceChildren(fragment); grid.setAttribute('aria-busy','false');
    message.hidden=filtered.length>0;
    if (!filtered.length) {message.querySelector('p').textContent='沒有符合的卡片。試試其他姓名或清除篩選。';retry.hidden=true;}
    document.querySelector('#card-page').textContent=`${page+1} / ${pages}`;
    previous.disabled=page===0; next.disabled=page>=pages-1;
    updateAddress();
  }
  function showDetail(index) {
    const card=filtered[index];
    if (!card) return;
    detailIndex=index;
    const image=document.querySelector('#detail-image');
    image.src=card.image; image.alt=`${card.name}・${card.team} 完整卡面`;
    document.querySelector('#detail-name').textContent=card.name;
    document.querySelector('#detail-team').textContent=card.team;
    document.querySelector('#detail-type').textContent=`${kinds[card.kind]} ／ ${card.league}`;
    const facts=document.querySelector('#detail-facts'); facts.replaceChildren();
    const addFact=(name,value)=>facts.append(text('dt',name),text('dd',value));
    addFact('卡色',rarities[card.rarity]);
    if (card.kind==='player') {
      addFact('位置',card.position); addFact('基礎 OVR',String(card.ovr));
      if (card.identity) addFact('身分',card.identity);
      if (card.draft_year) addFact('新秀年度',String(card.draft_year));
    } else {
      if (card.specialty) addFact('特色',card.specialty);
      if (card.roles) addFact('可用席位',card.roles.map(role=>({head_coach:'總教練',assistant_coach:'助理教練',cheerleaders:'應援席'})[role]).join('、'));
    }
    const effects=document.querySelector('#detail-effects'); effects.replaceChildren();
    for (const caption of card.effects||[]) effects.append(text('p',caption));
    document.querySelector('#detail-career').textContent=card.career||'';
    document.querySelector('#detail-note').textContent=card.kind==='player'?'此處展示未特訓卡面，能力值以實際遊戲版本為準。':'開發預覽；正式能力、開放時間與取得方式以遊戲公告為準。';
    document.querySelector('#detail-index').textContent=`${index+1} / ${filtered.length}`;
    document.querySelector('#previous-card').disabled=index===0;
    document.querySelector('#next-card').disabled=index===filtered.length-1;
    if (!dialog.open) dialog.showModal();
  }
  async function loadCatalog() {
    const attempt=++loadNumber;
    result.textContent='正在載入卡片…'; retry.hidden=true; message.hidden=true; grid.setAttribute('aria-busy','true');
    try {
      const response=await fetch(main.dataset.catalog);
      if (!response.ok) throw new Error('Catalog not available');
      const catalog=await response.json();
      if (catalog.version!==1||!Array.isArray(catalog.cards)||!catalog.cards.length||catalog.cards.some(card=>!Object.hasOwn(kinds,card.kind)||!card.name||!card.team||!Object.hasOwn(rarities,card.rarity)||!safeImage(card.image)||!safeImage(card.thumbnail))) throw new Error('Invalid card catalog');
      if (attempt!==loadNumber) return;
      cards=catalog.cards;
      league.length=1; team.length=1; populateFilters();
      document.querySelectorAll('[data-kind]').forEach(button=>button.querySelector('span').textContent=cards.filter(card=>card.kind===button.dataset.kind).length);
      render();
    } catch {
      if (attempt!==loadNumber) return;
      grid.setAttribute('aria-busy','false'); result.textContent='卡片預覽暫時無法載入'; message.hidden=false;
      message.querySelector('p').textContent='連線暫時中斷，請重新載入卡片。'; retry.hidden=false;
    }
  }
  document.querySelector('.catalog-filters').addEventListener('submit',event=>event.preventDefault());
  [search,league,team].forEach(control=>control.addEventListener('input',()=>{page=0;render();}));
  document.querySelectorAll('[data-kind]').forEach(button=>button.addEventListener('click',()=>{kind=button.dataset.kind;page=0;render();}));
  document.querySelector('.reset-filters').addEventListener('click',()=>{search.value='';league.value='';team.value='';page=0;render();});
  previous.addEventListener('click',()=>{page--;render();grid.scrollIntoView({block:'start'});});
  next.addEventListener('click',()=>{page++;render();grid.scrollIntoView({block:'start'});});
  retry.addEventListener('click',loadCatalog);
  document.querySelector('.close-detail').addEventListener('click',()=>dialog.close());
  dialog.addEventListener('click',event=>{if(event.target===dialog){const box=dialog.getBoundingClientRect();if(event.clientX<box.left||event.clientX>box.right||event.clientY<box.top||event.clientY>box.bottom)dialog.close();}});
  dialog.addEventListener('close',()=>{if(returnFocus?.isConnected)returnFocus.focus({preventScroll:true});});
  document.querySelector('#previous-card').addEventListener('click',()=>showDetail(detailIndex-1));
  document.querySelector('#next-card').addEventListener('click',()=>showDetail(detailIndex+1));
  dialog.addEventListener('keydown',event=>{if(event.key==='ArrowLeft'){event.preventDefault();showDetail(detailIndex-1);}if(event.key==='ArrowRight'){event.preventDefault();showDetail(detailIndex+1);}});
  loadCatalog();
})();
