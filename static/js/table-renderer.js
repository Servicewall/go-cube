/**
 * Table Renderer
 * 渲染数据到表格 DOM，支持多表格类型和列配置
 */

class TableRenderer {
  constructor() {
    this.currentTab = 'access';
    this.currentColumns = CONFIG.DEFAULT_COLUMNS[this.currentTab];
    this.tableConfigs = {
      'access': {
        tbodyId: 'access-table-body',
        tableId: 'table-access',
        theadId: 'access-thead'
      },
      'sensitive': {
        tbodyId: 'sensitive-table-body',
        tableId: 'table-sensitive',
        theadId: 'sensitive-thead'
      },
      'file': {
        tbodyId: 'file-table-body',
        tableId: 'table-file',
        theadId: 'file-thead'
      }
    };
    
    // 初始化当前表格
    this.updateCurrentTable();
  }

  // 更新当前表格配置
  updateCurrentTable() {
    const config = this.tableConfigs[this.currentTab];
    this.tbody = document.getElementById(config.tbodyId);
    this.table = document.getElementById(config.tableId);
    this.thead = document.getElementById(config.theadId);
    
    // 加载保存的列配置
    if (window.columnSettings) {
      // 确保columnSettings的currentTab与表格渲染器同步
      window.columnSettings.currentTab = this.currentTab;
      this.currentColumns = window.columnSettings.getCurrentColumns();
    } else {
      // 如果columnSettings还没有初始化，使用默认配置
      this.currentColumns = CONFIG.DEFAULT_COLUMNS[this.currentTab];
    }
  }

  /**
   * 切换表格类型
   * @param {string} tab - 表格类型
   */
  switchTab(tab) {
    this.currentTab = tab;
    this.updateCurrentTable();
    this.updateTableHeader();
  }

  /**
   * 更新列配置
   * @param {Array} columns - 新的列配置
   */
  updateColumns(columns) {
    this.currentColumns = columns;
    this.updateTableHeader();
  }

  /**
   * 更新表格头部
   */
  updateTableHeader() {
    if (!this.thead) return;
    
    const columnConfig = CONFIG.COLUMN_CONFIG['AccessView'];
    let headerHtml = `
      <tr class="text-[11px] text-slate-500 uppercase tracking-wider font-bold">
        <th class="w-6"></th>
    `;
    
    this.currentColumns.forEach(columnKey => {
      const config = columnConfig[columnKey];
      if (config) {
        headerHtml += `<th class="${config.width}">${config.name}</th>`;
      }
    });
    
    headerHtml += `<th class="w-8"></th></tr>`;
    this.thead.innerHTML = headerHtml;
  }

  /**
   * 清空表格内容
   */
  clear() {
    if (this.tbody) {
      this.tbody.innerHTML = '';
    }
  }

  /**
   * 显示加载状态
   */
  showLoading() {
    if (!this.tbody) return;
    
    const colspan = this.currentColumns.length + 2; // +2 for 序号列和操作列
    this.tbody.innerHTML = `
      <tr>
        <td colspan="${colspan}" class="text-center py-12 text-slate-500">
          <i class="fa-solid fa-circle-notch fa-spin text-2xl mb-3"></i>
          <div class="text-xs">正在加载数据...</div>
        </td>
      </tr>
    `;
  }

  /**
   * 显示空状态
   */
  showEmpty() {
    if (!this.tbody) return;
    
    const colspan = this.currentColumns.length + 2;
    this.tbody.innerHTML = `
      <tr>
        <td colspan="${colspan}" class="text-center py-12 text-slate-500">
          <i class="fa-solid fa-inbox text-3xl mb-3 text-slate-600"></i>
          <div class="text-xs">没有找到匹配的记录</div>
          <div class="text-[10px] text-slate-600 mt-1">请尝试调整过滤条件</div>
        </td>
      </tr>
    `;
  }

  /**
   * 显示错误状态
   * @param {string} message - 错误信息
   */
  showError(message) {
    if (!this.tbody) return;
    
    const colspan = this.currentColumns.length + 2;
    this.tbody.innerHTML = `
      <tr>
        <td colspan="${colspan}" class="text-center py-12 text-red-400">
          <i class="fa-solid fa-circle-exclamation text-2xl mb-3"></i>
          <div class="text-xs">${message}</div>
        </td>
      </tr>
    `;
  }

  /**
   * 渲染表格数据
   * @param {Array} records - 记录数组
   */
  renderRecords(records) {
    this.beginStream();
    if (!records || !records.length) {
      this.showEmpty();
      return;
    }
    records.forEach(r => this.appendRow(r));
  }

  beginStream() {
    if (!this.tbody) return;
    this.tbody.innerHTML = '';
    this._rowIdx = 0;
  }

  appendRow(rec) {
    if (!this.tbody) return;
    const idx = this._rowIdx++;
    const row = this.createRow(rec, idx);
    const detailsRow = this.createDetailsRow(rec, idx);
    this.tbody.appendChild(row);
    this.tbody.appendChild(detailsRow);
  }

  /**
   * 渲染访问记录表格（向后兼容）
   * @param {Array} records - 记录数组
   */
  renderAccessRecords(records) {
    this.renderRecords(records);
  }

  /**
   * 格式化时间
   * @param {string} ts - 时间字符串
   * @returns {string} 格式化后的时间
   */
  formatTime(ts) {
    if (!ts) return '-';
    try {
      const date = new Date(ts);
      return date.toLocaleTimeString('zh-CN', { hour12: false }) + '.' + String(date.getMilliseconds()).padStart(3, '0');
    } catch (e) {
      return ts || '-';
    }
  }

  /**
   * 创建表格行
   * @param {Object} rec - 记录数据
   * @param {number} idx - 索引
   * @returns {HTMLElement} tr 元素
   */
  createRow(rec, idx) {
    const tr = document.createElement('tr');
    tr.className = 'hover:bg-[#161b22] transition-colors group cursor-pointer';
    const recId = `rec-${this.currentTab}-${idx}`;
    tr.onclick = () => {
      const detailsRow = document.getElementById(`${recId}-details`);
      const caret = document.getElementById(`caret-${recId}`);

      if (detailsRow) {
        if (detailsRow.classList.contains('active')) {
          detailsRow.classList.remove('active');
          if (caret) caret.style.transform = 'rotate(0deg)';
        } else {
          detailsRow.classList.add('active');
          if (caret) caret.style.transform = 'rotate(90deg)';
        }
      }
    };

    let rowHtml = `
      <td class="text-center">
        <i class="fa-solid fa-caret-right text-[9px] text-slate-600 transition-transform" id="caret-${recId}"></i>
      </td>
    `;

    // 根据当前列配置生成单元格
    this.currentColumns.forEach(columnKey => {
      const cellContent = this.formatCellContent(rec, columnKey);
      rowHtml += `<td>${cellContent}</td>`;
    });

    rowHtml += `
      <td><i class="fa-solid fa-ellipsis opacity-0 group-hover:opacity-100 text-slate-500"></i></td>
    `;

    tr.innerHTML = rowHtml;
    return tr;
  }

  /**
   * 创建详情行
   * @param {Object} rec - 记录数据
   * @param {number} idx - 索引
   * @returns {HTMLElement} tr 元素
   */
  createDetailsRow(rec, idx) {
    const tr = document.createElement('tr');
    tr.className = 'details-row';
    tr.id = `rec-${this.currentTab}-${idx}-details`;

    // 根据当前视图类型创建不同的详情内容
    if (this.currentTab === 'sensitive') {
      return this.createSensitiveDetailsRow(rec, idx, tr);
    } else if (this.currentTab === 'file') {
      return this.createFileDetailsRow(rec, idx, tr);
    } else {
      return this.createAccessDetailsRow(rec, idx, tr);
    }
  }

  /**
   * 创建访问记录详情行
   */
  createAccessDetailsRow(rec, idx, tr) {
    const colspan = this.currentColumns.length + 2;

    // 根据处理结果确定边框颜色
    const result = rec['AccessView.result'] || rec['result'] || '';
    const isBlocked = result === 'protect' || result === '保护';
    const borderColor = isBlocked ? 'border-red-500/50' : 'border-blue-500/50';

    // 提取详情数据
    const id = rec['AccessView.id'] || rec['id'] || '-';
    const devType = rec['AccessView.devType'] || rec['devType'] || '-';
    const topoNetwork = rec['AccessView.topoNetwork'] || rec['topoNetwork'] || '公网';
    const uid = rec['AccessView.uid'] || rec['uid'] || '-';
    const sid = rec['AccessView.sid'] || rec['sid'] || '-';
    const uaFp = rec['AccessView.uaFp'] || rec['uaFp'] || '-';
    const resultScore = rec['AccessView.resultScore'] || rec['resultScore'] || '0';
    const reason = rec['AccessView.reason'] || rec['reason'] || '-';
    const nodeName = rec['AccessView.nodeName'] || rec['nodeName'] || '-';
    const upstream = rec['AccessView.upstream'] || rec['upstream'] || '-';
    const protocol = rec['AccessView.protocol'] || rec['protocol'] || 'HTTP';
    const dstNode = rec['AccessView.dstNode'] || rec['dstNode'] || '-';
    const reqHead = rec['AccessView.reqHead'] || rec['reqHead'] || '';
    const reqBody = rec['AccessView.reqBody'] || rec['reqBody'] || '';
    const respHead = rec['AccessView.respHead'] || rec['respHead'] || '';
    const respBody = rec['AccessView.respBody'] || rec['respBody'] || '';
    const reqContentLength = rec['AccessView.reqContentLength'] || rec['reqContentLength'] || '0';
    const respContentLength = rec['AccessView.respContentLength'] || rec['respContentLength'] || '0';
    const host = rec['AccessView.host'] || rec['host'] || '';
    const url = rec['AccessView.url'] || rec['url'] || '';
    const method = rec['AccessView.method'] || rec['method'] || 'GET';
    const status = rec['AccessView.status'] || rec['status'] || '200';

    // 构建 HTTP 请求摘要
    let reqSummary = '';
    if (reqHead) {
      try {
        const headers = typeof reqHead === 'string' ? JSON.parse(reqHead) : reqHead;
        reqSummary = `${method} ${url} ${protocol}/1.1\nHost: ${host}`;
        if (headers && typeof headers === 'object') {
          Object.entries(headers).forEach(([key, value]) => {
            reqSummary += `\n${key}: ${value}`;
          });
        }
        if (reqBody) {
          reqSummary += `\n\n${typeof reqBody === 'string' ? reqBody : JSON.stringify(reqBody, null, 2)}`;
        }
      } catch (e) {
        reqSummary = `${method} ${url} ${protocol}/1.1\nHost: ${host}\n\n${reqBody || ''}`;
      }
    } else {
      reqSummary = `${method} ${url} ${protocol}/1.1\nHost: ${host}`;
    }

    // 构建响应详情
    let respSummary = '';
    if (respHead) {
      try {
        const headers = typeof respHead === 'string' ? JSON.parse(respHead) : respHead;
        respSummary = `${protocol}/1.1 ${status}`;
        if (headers && typeof headers === 'object') {
          Object.entries(headers).forEach(([key, value]) => {
            respSummary += `\n${key}: ${value}`;
          });
        }
        if (respBody) {
          respSummary += `\n\n${typeof respBody === 'string' ? respBody : JSON.stringify(respBody, null, 2)}`;
        }
      } catch (e) {
        respSummary = `${protocol}/1.1 ${status}\n\n${respBody || ''}`;
      }
    } else {
      respSummary = `${protocol}/1.1 ${status}`;
    }

    tr.innerHTML = `
      <td></td>
      <td colspan="${colspan - 1}" class="p-0">
        <div class="p-4 bg-[#010409] border-l-2 ${borderColor} my-1 mx-2 rounded-r">
          <div class="grid grid-cols-4 gap-x-8 gap-y-3">
            <div>
              <div class="text-[9px] text-slate-500 font-bold uppercase">基础信息</div>
              <div class="mt-1 space-y-1">
                <div class="text-[10px]">ID: <span class="text-slate-300">${id}</span></div>
                <div class="text-[10px]">终端: <span class="text-slate-300">${devType}</span></div>
                <div class="text-[10px]">网络: <span class="text-slate-300">${topoNetwork}</span></div>
              </div>
            </div>
            <div>
              <div class="text-[9px] text-slate-500 font-bold uppercase">身份溯源</div>
              <div class="mt-1 space-y-1">
                <div class="text-[10px]">用户 ID: <span class="text-slate-300">${uid}</span></div>
                <div class="text-[10px]">设备 ID: <span class="text-slate-300">${sid}</span></div>
                <div class="text-[10px]">指纹: <span class="text-slate-300">${uaFp}</span></div>
              </div>
            </div>
            <div>
              <div class="text-[9px] text-slate-500 font-bold uppercase">防护详情</div>
              <div class="mt-1 space-y-1">
                <div class="text-[10px]">风险得分: <span class="${isBlocked ? 'text-red-400' : 'text-green-400'}">${resultScore}</span></div>
                <div class="text-[10px]">动作: <span class="${isBlocked ? 'text-red-400' : 'text-green-400'}">${isBlocked ? '拦截' : '放行'}</span></div>
                <div class="text-[10px]">原因: <span class="text-slate-300">${reason}</span></div>
              </div>
            </div>
            <div>
              <div class="text-[9px] text-slate-500 font-bold uppercase">节点信息</div>
              <div class="mt-1 space-y-1">
                <div class="text-[10px]">节点: <span class="text-slate-300">${nodeName}</span></div>
                <div class="text-[10px]">目标: <span class="text-slate-300">${upstream || dstNode}</span></div>
                <div class="text-[10px]">协议: <span class="text-slate-300">${protocol}</span></div>
              </div>
            </div>
          </div>
          <div class="mt-4 grid grid-cols-2 gap-4">
            <div class="space-y-1">
              <div class="flex justify-between items-center">
                <span class="text-[9px] text-slate-500 font-bold">HTTP 请求摘要</span>
                <span class="text-[9px] text-slate-600">大小: ${this.formatBytes(parseInt(reqContentLength) || 0)}</span>
              </div>
              <div class="code-block h-28 overflow-auto whitespace-pre font-mono text-[10px]">${this.escapeHtml(reqSummary)}</div>
            </div>
            <div class="space-y-1">
              <div class="flex justify-between items-center">
                <span class="text-[9px] text-slate-500 font-bold">响应详情</span>
                <span class="text-[9px] text-slate-600">大小: ${this.formatBytes(parseInt(respContentLength) || 0)}</span>
              </div>
              <div class="code-block h-28 overflow-auto whitespace-pre font-mono text-[10px]">${this.escapeHtml(respSummary)}</div>
            </div>
          </div>
        </div>
      </td>
    `;

    return tr;
  }

  /**
   * 标准化数组数据（处理 ClickHouse 返回的各种格式）
   */
  normalizeArray(value) {
    if (!value) return [];
    if (Array.isArray(value)) return value;
    if (typeof value === 'string') {
      // 处理 "['a', 'b', 'c']" 格式的字符串
      if (value.startsWith('[') && value.endsWith(']')) {
        try {
          return JSON.parse(value.replace(/'/g, '"'));
        } catch (e) {
          // 如果解析失败，按逗号分割
          return value.slice(1, -1).split(',').map(s => s.trim().replace(/^['"]|['"]$/g, '')).filter(Boolean);
        }
      }
      return [value];
    }
    return [];
  }

  /**
   * 创建敏感数据详情行
   */
  createSensitiveDetailsRow(rec, idx, tr) {
    const colspan = this.currentColumns.length + 2;

    // 获取敏感数据相关信息 - 支持多种字段命名
    const sensScore = rec['AccessView.sensScore'] || rec['sensScore'] || rec['sens_score'] || '0';
    const sensScoreName = rec['AccessView.sensScoreName'] || rec['sensScoreName'] || '-';

    // 请求敏感数据 - 支持数组和字符串格式，尝试多种可能的字段名
    let reqSensKey = rec['AccessView.reqSensKey'] || rec['reqSensKey'] || rec['req_sens_k'] || rec['req_sens_key'] || [];
    let reqSensValue = rec['AccessView.reqSensValue'] || rec['reqSensValue'] || rec['req_sens_v'] || rec['req_sens_val'] || rec['req_sens_value'] || [];
    let reqSensNum = rec['AccessView.reqSensKeyNum'] || rec['reqSensKeyNum'] || rec['req_sens_key_num'] || 0;

    // 响应敏感数据
    let respSensKey = rec['AccessView.respSensKey'] || rec['respSensKey'] || rec['res_sens_k'] || rec['resp_sens_key'] || [];
    let respSensValue = rec['AccessView.respSensValue'] || rec['respSensValue'] || rec['res_sens_v'] || rec['resp_sens_val'] || rec['resp_sens_value'] || [];
    let respSensNum = rec['AccessView.resSensKeyNum'] || rec['resSensKeyNum'] || rec['respSensKeyNum'] || rec['res_sens_key_num'] || 0;

    // 处理 ClickHouse 数组格式 (可能是字符串 "['a', 'b']" 或实际数组)
    reqSensKey = this.normalizeArray(reqSensKey);
    reqSensValue = this.normalizeArray(reqSensValue);
    respSensKey = this.normalizeArray(respSensKey);
    respSensValue = this.normalizeArray(respSensValue);

    const reqSensValNum = rec['AccessView.reqSensValNum'] || rec['reqSensValNum'] || rec['req_sens_v_num'] || reqSensNum || reqSensValue.length || 0;
    const respSensValNum = rec['AccessView.respSensValNum'] || rec['respSensValNum'] || rec['res_sens_v_num'] || respSensNum || respSensValue.length || 0;
    const result = rec['AccessView.result'] || rec['result'] || '';

    // 判断是否有敏感数据
    const hasReqSens = reqSensKey.length > 0;
    const hasRespSens = respSensKey.length > 0;
    const hasSensitive = hasReqSens || hasRespSens;

    console.log('Sensitive data debug:', {
      recKeys: Object.keys(rec).filter(k => k.toLowerCase().includes('sens')),
      reqSensKeyRaw: rec['AccessView.reqSensKey'] || rec['reqSensKey'] || rec['req_sens_k'],
      reqSensValueRaw: rec['AccessView.reqSensValue'] || rec['reqSensValue'] || rec['req_sens_v'],
      hasReqSens, reqSensKey, reqSensValue, hasRespSens, respSensKey, respSensValue, reqSensNum, respSensNum
    });

    // 根据敏感程度确定边框颜色
    const score = parseFloat(sensScore);
    let borderColor = 'border-blue-500/50';
    if (score >= 80) borderColor = 'border-red-500/50';
    else if (score >= 60) borderColor = 'border-amber-500/50';
    else if (score >= 40) borderColor = 'border-yellow-500/50';

    // 处理敏感数据分布统计 - 紧凑标签形式
    const sensDistribution = this.calculateSensDistribution(reqSensKey, respSensKey);
    const distributionHtml = sensDistribution.map(([type, count]) => `
      <span class="inline-flex items-center px-2 py-0.5 rounded text-[10px] bg-amber-900/30 text-amber-400 border border-amber-700/30">
        ${type}: ${count}
      </span>
    `).join('');

    // 构建敏感数据详情表
    let sensTableHtml = '';
    if (hasSensitive) {
      const rows = [];
      
      // 请求中的敏感数据
      if (hasReqSens) {
        for (let i = 0; i < reqSensKey.length; i++) {
          rows.push({
            type: reqSensKey[i],
            value: reqSensValue[i] || '-',
            source: '请求',
            category: this.getSensCategory(reqSensKey[i])
          });
        }
      }
      
      // 响应中的敏感数据
      if (hasRespSens) {
        for (let i = 0; i < respSensKey.length; i++) {
          rows.push({
            type: respSensKey[i],
            value: respSensValue[i] || '-',
            source: '响应',
            category: this.getSensCategory(respSensKey[i])
          });
        }
      }

      // 生成表格行 HTML
      const tableRowsHtml = rows.slice(0, 10).map(row => `
        <tr class="border-b border-slate-800/50">
          <td class="py-1.5 px-2 text-[10px] text-slate-300">${row.type}</td>
          <td class="py-1.5 px-2 text-[10px] text-slate-400 font-mono truncate max-w-[200px]" title="${row.value}">${row.value}</td>
          <td class="py-1.5 px-2 text-[10px]">
            <span class="${row.source === '请求' ? 'text-blue-400' : 'text-green-400'}">${row.source}</span>
          </td>
          <td class="py-1.5 px-2 text-[10px]">
            <span class="sens-tag">${row.category}</span>
          </td>
        </tr>
      `).join('');

      sensTableHtml = `
        <div class="mt-4">
          <div class="text-[9px] text-slate-500 font-bold uppercase mb-2">检测到的敏感数据详情</div>
          <div class="bg-slate-900/30 rounded overflow-hidden">
            <table class="w-full text-left">
              <thead class="bg-slate-800/50">
                <tr>
                  <th class="py-2 px-2 text-[10px] text-slate-400 font-bold">数据类型</th>
                  <th class="py-2 px-2 text-[10px] text-slate-400 font-bold">值 (已脱敏)</th>
                  <th class="py-2 px-2 text-[10px] text-slate-400 font-bold">来源</th>
                  <th class="py-2 px-2 text-[10px] text-slate-400 font-bold">分类</th>
                </tr>
              </thead>
              <tbody>
                ${tableRowsHtml}
                ${rows.length > 10 ? `
                  <tr>
                    <td colspan="4" class="py-2 px-2 text-[10px] text-slate-500 text-center">
                      还有 ${rows.length - 10} 条敏感数据...
                    </td>
                  </tr>
                ` : ''}
              </tbody>
            </table>
          </div>
        </div>
      `;
    }

    // 简化展示：突出敏感数据类别和值
    tr.innerHTML = `
      <td></td>
      <td colspan="${colspan - 1}" class="p-0">
        <div class="p-4 bg-[#010409] border-l-2 ${borderColor} my-1 mx-2 rounded-r">
          ${hasSensitive ? `
            <!-- 敏感数据详情表格 -->
            ${sensTableHtml}

            <!-- 分布统计 -->
            <div class="mt-3 text-[9px] text-slate-500 font-bold uppercase">敏感数据类型分布</div>
            <div class="mt-1 flex flex-wrap gap-2">
              ${distributionHtml}
            </div>
          ` : `
            <div class="text-center py-4 text-slate-500">
              <i class="fa-solid fa-shield-check text-2xl mb-2 text-green-500/50"></i>
              <div class="text-xs">未检测到敏感数据</div>
            </div>
          `}

          <!-- 简要信息 -->
          <div class="mt-3 flex items-center justify-between text-[10px] text-slate-400 border-t border-slate-800 pt-2">
            <span>请求: ${reqSensValNum} 条敏感数据</span>
            <span>响应: ${respSensValNum} 条敏感数据</span>
            <span>敏感得分: <span class="${score >= 60 ? 'text-red-400' : 'text-amber-400'}">${sensScore}</span></span>
          </div>
        </div>
      </td>
    `;

    return tr;
  }

  /**
   * 计算敏感数据分布
   */
  calculateSensDistribution(reqSensKey, respSensKey) {
    const distribution = new Map();

    // 统计请求中的敏感数据
    reqSensKey.forEach(key => {
      distribution.set(key, (distribution.get(key) || 0) + 1);
    });

    // 统计响应中的敏感数据
    respSensKey.forEach(key => {
      distribution.set(key, (distribution.get(key) || 0) + 1);
    });

    // 转换为数组并按数量排序
    return Array.from(distribution.entries()).sort((a, b) => b[1] - a[1]);
  }

  /**
   * 获取敏感数据分类
   */
  getSensCategory(key) {
    // 常见敏感数据类型映射
    const categoryMap = {
      '身份证号': '个人敏感信息',
      '手机号': '个人敏感信息',
      '银行卡': '金融敏感信息',
      '姓名': '个人基本信息',
      '地址': '个人基本信息',
      '邮箱': '个人基本信息',
      '密码': '账户敏感信息',
      'token': '账户敏感信息',
      'cookie': '账户敏感信息',
      'session': '账户敏感信息'
    };
    
    // 尝试匹配
    for (const [pattern, category] of Object.entries(categoryMap)) {
      if (key.includes(pattern)) {
        return category;
      }
    }
    
    return '其他敏感信息';
  }

  /**
   * 创建文件传输详情行
   */
  createFileDetailsRow(rec, idx, tr) {
    const colspan = this.currentColumns.length + 2;

    // 提取文件相关信息
    const fileName = rec['AccessView.fileName'] || rec['fileName'] || rec['file_name'] || '-';
    const fileType = rec['AccessView.fileType'] || rec['fileType'] || rec['file_type'] || '-';
    const fileSize = rec['AccessView.fileSize'] || rec['fileSize'] || rec['file_size'] || '0';
    const fileMd5 = rec['AccessView.fileMd5'] || rec['fileMd5'] || rec['file_md5'] || '-';
    const fileDirection = rec['AccessView.fileDirection'] || rec['fileDirection'] || rec['file_direction'] || '-';
    const isEncrypted = rec['AccessView.isEncrypted'] || rec['isEncrypted'] || rec['is_encrypted'] || 'false';
    const fileSensKey = rec['AccessView.fileSensKey'] || rec['fileSensKey'] || rec['file_sens_k'] || [];
    const fileSensVal = rec['AccessView.fileSensVal'] || rec['fileSensVal'] || rec['file_sens_v'] || [];
    
    // 获取文件敏感数据
    const fileSensCount = Array.isArray(fileSensKey) ? fileSensKey.length : 0;
    const hasFileSens = fileSensCount > 0;

    // 确定边框颜色
    let borderColor = 'border-blue-500/50';
    if (hasFileSens) borderColor = 'border-red-500/50';

    // 构建文件敏感数据列表
    let sensListHtml = '';
    if (hasFileSens) {
      const sensItems = fileSensKey.slice(0, 5).map((key, i) => `
        <div class="flex justify-between text-[10px] py-1 border-b border-slate-800/50 last:border-0">
          <span class="text-slate-300">${key}</span>
          <span class="text-amber-400">${fileSensVal[i] ? fileSensVal[i].substring(0, 50) + '...' : '-'}</span>
        </div>
      `).join('');
      
      sensListHtml = `
        <div class="bg-slate-900/50 p-2 rounded border border-amber-900/20">
          <div class="text-[9px] text-slate-500 font-bold uppercase mb-2">文件敏感内容 (${fileSensCount} 处)</div>
          ${sensItems}
          ${fileSensCount > 5 ? `<div class="text-[10px] text-slate-500 mt-2">还有 ${fileSensCount - 5} 处...</div>` : ''}
        </div>
      `;
    }

    tr.innerHTML = `
      <td></td>
      <td colspan="${colspan - 1}" class="p-0">
        <div class="p-4 bg-[#010409] border-l-2 ${borderColor} my-1 mx-2 rounded-r">
          <div class="grid grid-cols-3 gap-6">
            <div>
              <div class="text-[9px] text-slate-500 font-bold uppercase mb-2">文件信息</div>
              <div class="space-y-1 text-[10px]">
                <div>文件名: <span class="text-slate-300">${fileName}</span></div>
                <div>大小: <span class="text-slate-300">${this.formatBytes(parseInt(fileSize) || 0)}</span></div>
                <div>类型: <span class="text-slate-300">${fileType}</span></div>
                <div>MD5: <span class="text-slate-300 mono">${fileMd5.substring(0, 16)}...</span></div>
                <div>加密: <span class="${isEncrypted === 'true' ? 'text-green-400' : 'text-slate-400'}">${isEncrypted === 'true' ? '是' : '否'}</span></div>
              </div>
            </div>
            <div>
              <div class="text-[9px] text-slate-500 font-bold uppercase mb-2">传输信息</div>
              <div class="space-y-1 text-[10px]">
                <div>方向: <span class="${fileDirection === '上传' ? 'text-blue-400' : 'text-green-400'}">${fileDirection}</span></div>
                <div>敏感检测: <span class="${hasFileSens ? 'text-red-400' : 'text-green-400'}">${hasFileSens ? `检测到 ${fileSensCount} 处` : '未检测到'}</span></div>
              </div>
            </div>
            ${hasFileSens ? `
            <div>
              ${sensListHtml}
              <div class="mt-2 space-y-1">
                <button class="w-full text-[9px] bg-blue-600/20 text-blue-400 border border-blue-500/30 py-1 rounded hover:bg-blue-600/30 transition-colors">
                  <i class="fa-solid fa-download mr-1"></i>下载样本分析
                </button>
                <button class="w-full text-[9px] bg-slate-800 text-slate-300 border border-slate-700 py-1 rounded hover:bg-slate-700 transition-colors">
                  <i class="fa-solid fa-eye mr-1"></i>查看内容预览
                </button>
              </div>
            </div>
            ` : `
            <div class="flex items-center justify-center">
              <div class="text-center">
                <i class="fa-solid fa-file-shield text-3xl text-green-500/30 mb-2"></i>
                <div class="text-[10px] text-slate-500">文件安全</div>
              </div>
            </div>
            `}
          </div>
        </div>
      </td>
    `;

    return tr;
  }

  /**
   * 转义 HTML 特殊字符
   * @param {string} text - 原始文本
   * @returns {string} 转义后的文本
   */
  escapeHtml(text) {
    if (!text) return '';
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  /**
   * 格式化单元格内容
   * @param {Object} rec - 记录数据
   * @param {string} columnKey - 列键
   * @returns {string} 格式化后的HTML
   */
  formatCellContent(rec, columnKey) {
    const value = rec[columnKey];
    const columnConfig = CONFIG.COLUMN_CONFIG['AccessView'][columnKey];
    
    if (!columnConfig) {
      return `<span class="text-slate-400">${value || '-'}</span>`;
    }

    // 通用 object 类型处理（Map/JSON）
    if (value && typeof value === 'object' && !Array.isArray(value)) {
      const entries = Object.entries(value);
      if (entries.length === 0) return '<span class="text-slate-600">-</span>';
      const formatted = entries.map(([k, v]) => `${k}(${v})`).join(', ');
      return `<span class="text-slate-400 text-[10px]" title="${formatted}">${formatted}</span>`;
    }

    // 根据列名进行特殊格式化
    switch (columnKey) {
      case 'AccessView.ts':
        return `<span class="text-slate-400">${this.formatTime(value)}</span>`;
        
      case 'AccessView.ip':
        const city = rec['AccessView.ipGeoCity'] || '';
        const province = rec['AccessView.ipGeoProvince'] || '';
        const location = city || province ? `${province}·${city}`.replace(/^·|·$/g, '') : '';
        return `
          <div class="flex flex-col">
            <span class="text-slate-200 font-mono">${value}</span>
            <span class="text-[9px] text-slate-600">${location}</span>
          </div>
        `;
        
      case 'AccessView.method':
        const method = (value || 'GET').toUpperCase();
        const methodClass = CONFIG.METHOD_COLORS[method] || CONFIG.DEFAULT_METHOD_COLOR;
        return `<span class="method-tag ${methodClass}">${method}</span>`;
        
      case 'AccessView.status':
        const statusCode = parseInt(value);
        let statusClass = 'bg-slate-800 text-slate-400 border-slate-700';
        if (statusCode >= 200 && statusCode < 300) {
          statusClass = 'bg-green-900/30 text-green-400 border-green-900/20';
        } else if (statusCode >= 400) {
          statusClass = 'bg-red-900/30 text-red-400 border-red-900/20';
        } else if (statusCode >= 300) {
          statusClass = 'bg-yellow-900/30 text-yellow-400 border-yellow-900/20';
        }
        return `<span class="status-tag ${statusClass}">${value}</span>`;
        
      case 'AccessView.resultType':
        const resultColor = value === '保护' ? 'text-red-400 font-bold' : 'text-green-500';
        return `<span class="${resultColor}">${value}</span>`;
        
      case 'AccessView.resultRisk':
        if (value && value !== '-') {
          const risks = Array.isArray(value) ? value : [value];
          const riskTags = risks.map(r => `<span class="risk-tag">${r}</span>`).join('');
          return riskTags;
        }
        return '<span class="text-slate-600">-</span>';

      case 'AccessView.fileDirection':
        if (value === '上传') {
          return '<span class="text-blue-400"><i class="fa-solid fa-upload mr-1"></i></span>';
        } else if (value === '下载') {
          return '<span class="text-green-400"><i class="fa-solid fa-download mr-1"></i></span>';
        }
        return '<span class="text-slate-600">-</span>';

      case 'AccessView.url':
        const assetName = rec['AccessView.assetName'] || '';
        return `
          <div class="flex flex-col">
            <span class="text-slate-200 truncate" title="${value}">${value}</span>
            ${assetName ? `<span class="text-[9px] text-blue-400">业务: ${assetName}</span>` : ''}
          </div>
        `;
        
      case 'AccessView.reqContentLength':
      case 'AccessView.respContentLength':
        if (value && value !== '-') {
          const bytes = parseInt(value);
          const formatted = this.formatBytes(bytes);
          return `<span class="text-slate-400">${formatted}</span>`;
        }
        return '<span class="text-slate-600">-</span>';
        
      case 'AccessView.sensScore':
        if (value && value !== '-') {
          const score = parseFloat(value);
          let scoreClass = 'text-slate-400';
          if (score >= 80) scoreClass = 'text-red-400 font-bold';
          else if (score >= 60) scoreClass = 'text-yellow-400';
          else if (score >= 40) scoreClass = 'text-blue-400';
          return `<span class="${scoreClass}">${score}</span>`;
        }
        return '<span class="text-slate-600">-</span>';

      default:
        const str = String(value ?? '');
        const display = str.length > 30 ? str.slice(0, 30) + '..' : str;
        return `<span class="text-slate-400" title="${this.escapeHtml(str)}">${this.escapeHtml(display)}</span>`;
    }
  }

  /**
   * 格式化字节大小
   * @param {number} bytes - 字节数
   * @returns {string} 格式化后的大小
   */
  formatBytes(bytes) {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
  }

  /**
   * 切换详情行显示
   * @param {string} recId - 记录 ID
   */
  toggleDetails(recId) {
    const detailsRow = document.getElementById(`${recId}-details`);
    const caret = document.getElementById(`caret-${recId}`);
    
    if (detailsRow) {
      if (detailsRow.classList.contains('active')) {
        detailsRow.classList.remove('active');
        if (caret) caret.style.transform = 'rotate(0deg)';
      } else {
        detailsRow.classList.add('active');
        if (caret) caret.style.transform = 'rotate(90deg)';
      }
    }
  }
}

// 导出供其他模块使用
if (typeof module !== 'undefined' && module.exports) {
  module.exports = TableRenderer;
}
