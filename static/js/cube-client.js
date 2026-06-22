/**
 * Cube API Client
 * 封装 Cube.js 兼容 API 的 JavaScript 客户端
 */

class CubeClient {
  constructor(baseURL = '') {
    this.baseURL = baseURL || window.location.origin;
  }

  /**
   * 通用查询方法
   * @param {Object} cubeQuery - Cube.js 格式的查询对象
   * @returns {Promise<Array>} 返回数据数组
   */
  async query(cubeQuery) {
    const queryString = encodeURIComponent(JSON.stringify(cubeQuery));
    const url = `${this.baseURL}/load?query=${queryString}`;

    try {
      const response = await fetch(url);

      if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`API 错误 (${response.status}): ${errorText}`);
      }

      const data = await response.json();

      if (data.results && data.results[0] && data.results[0].data) {
        return data.results[0].data;
      }

      return [];
    } catch (error) {
      console.error('Cube API 调用失败:', error);
      throw error;
    }
  }

  /**
   * 流式查询 — NDJSON 逐行回调
   * @param {Object} cubeQuery - Cube.js 格式的查询对象
   * @param {Function} onRow - 每行回调 (row) => void
   * @param {Function} onError - 错误回调 (err) => void
   */
  async queryStream(cubeQuery, onRow, onError) {
    cubeQuery.ungrouped = true;
    const url = `${this.baseURL}/load?query=${encodeURIComponent(JSON.stringify(cubeQuery))}`;
    const response = await fetch(url, { headers: { 'Accept': 'application/x-ndjson' } });
    if (!response.ok) throw new Error(`API ${response.status}`);

    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let buffer = '';

    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split('\n');
        buffer = lines.pop();
        for (const line of lines) {
          if (!line.trim()) continue;
          try {
            const row = JSON.parse(line);
            if (row.error) { onError && onError(new Error(row.error)); return; }
            onRow(row);
          } catch (e) {
            if (e.message !== 'row.error') continue;
            throw e;
          }
        }
      }
    } finally {
      reader.releaseLock();
    }
  }

  /**
   * 获取访问记录
   * @param {Object} params - 查询参数
   * @param {string} params.timeRange - 时间范围
   * @param {number} params.limit - 返回记录数限制
   * @param {Array} params.filters - 表达式生成的 filters
   * @param {string} params.viewType - 视图类型 ('access', 'sensitive', 'file')
   * @returns {Promise<Array>} 访问记录数组
   */
  async getAccessRecords(params = {}) {
    const {
      timeRange,
      limit = CONFIG.DEFAULT_LIMIT,
      filters = [],
      viewType = 'access'
    } = params;

    // 根据视图类型选择 dimensions
    let dimensions;
    switch (viewType) {
      case 'sensitive':
        dimensions = CONFIG.SENSITIVE_VIEW_DIMENSIONS;
        break;
      case 'file':
        dimensions = CONFIG.FILE_VIEW_DIMENSIONS || CONFIG.ACCESS_VIEW_DIMENSIONS;
        break;
      default:
        dimensions = CONFIG.ACCESS_VIEW_DIMENSIONS;
    }

    const query = {
      dimensions: dimensions,
      measures: [],
      filters: filters,
      timeDimensions: [{
        dimension: 'AccessView.ts',
        dateRange: timeRange || CONFIG.TIME_RANGES['最近 15 分钟']
      }],
      limit: limit,
      order: {
        'AccessView.ts': 'desc'
      }
    };

    return this.query(query);
  }

  /**
   * 流式获取访问记录
   * @param {Object} params - 查询参数
   * @param {Function} onRow - 每行回调 (row) => void
   * @param {Function} onError - 错误回调 (err) => void
   */
  async getAccessRecordsStream(params = {}, onRow, onError) {
    const {
      timeRange, limit = CONFIG.DEFAULT_LIMIT,
      filters = [], viewType = 'access'
    } = params;

    let dimensions;
    switch (viewType) {
      case 'sensitive': dimensions = CONFIG.SENSITIVE_VIEW_DIMENSIONS; break;
      case 'file': dimensions = CONFIG.FILE_VIEW_DIMENSIONS || CONFIG.ACCESS_VIEW_DIMENSIONS; break;
      default: dimensions = CONFIG.ACCESS_VIEW_DIMENSIONS;
    }

    return this.queryStream({
      dimensions, measures: [], filters,
      timeDimensions: [{ dimension: 'AccessView.ts', dateRange: timeRange || CONFIG.TIME_RANGES['最近 15 分钟'] }],
      limit, order: { 'AccessView.ts': 'desc' }
    }, onRow, onError);
  }

  /**
   * 健康检查
   * @returns {Promise<boolean>} 服务是否可用
   */
  async healthCheck() {
    try {
      const response = await fetch(`${this.baseURL}/health`);
      return response.ok;
    } catch {
      return false;
    }
  }
}

// 导出供其他模块使用
if (typeof module !== 'undefined' && module.exports) {
  module.exports = CubeClient;
}
