/**
 * 应用配置文件
 * 集中管理所有配置项
 */

const CONFIG = {
  // API 配置
  API_BASE: window.location.origin,
  DEFAULT_LIMIT: 50,

  // 时间范围映射
  TIME_RANGES: {
    '今天': 'today',
    '最近 15 分钟': 'from 15 minutes ago to now',
    '最近 1 小时': 'from 1 hour ago to now',
    '最近 24 小时': 'from 24 hours ago to now',
    '最近 7 天': 'from 7 days ago to now'
  },

  // 时间范围显示映射（用于 SQL 预览）
  TIME_RANGE_DISPLAY: {
    'today': 'today()',
    'from 15 minutes ago to now': 'now()-15m',
    'from 1 hour ago to now': 'now()-1h',
    'from 24 hours ago to now': 'now()-24h',
    'from 7 days ago to now': 'now()-7d'
  },
  
  // HTTP 方法颜色映射
  METHOD_COLORS: {
    'GET': 'bg-green-900/30 text-green-400',
    'POST': 'bg-blue-900/30 text-blue-400',
    'PUT': 'bg-yellow-900/30 text-yellow-400',
    'DELETE': 'bg-red-900/30 text-red-400',
    'PATCH': 'bg-purple-900/30 text-purple-400'
  },
  
  // 默认方法颜色
  DEFAULT_METHOD_COLOR: 'bg-slate-800 text-slate-400',
  
  // 查询字段列表
  ACCESS_VIEW_DIMENSIONS: [
    'AccessView.ts',
    'AccessView.ip',
    'AccessView.ipGeoCity',
    'AccessView.ipGeoProvince',
    'AccessView.method',
    'AccessView.host',
    'AccessView.url',
    'AccessView.assetName',
    'AccessView.status',
    'AccessView.resultType',
    'AccessView.resultRisk',
    'AccessView.uid',
    'AccessView.sid',
    'AccessView.reason',
    'AccessView.protocol',
    'AccessView.reqContentLength',
    'AccessView.respContentLength'
  ],

  // 敏感数据视图查询字段
  SENSITIVE_VIEW_DIMENSIONS: [
    'AccessView.ts',
    'AccessView.ip',
    'AccessView.url',
    'AccessView.reqSensKey',
    'AccessView.reqSensValue',
    'AccessView.respSensKey',
    'AccessView.respSensValue',
    'AccessView.reqSensKeyNum',
    'AccessView.resSensKeyNum',
    'AccessView.sensScore',
    'AccessView.resultType',
    'AccessView.reason'
  ],

  // 文件传输视图查询字段
  FILE_VIEW_DIMENSIONS: [
    'AccessView.ts',
    'AccessView.ip',
    'AccessView.uid',
    'AccessView.url',
    'AccessView.fileName',
    'AccessView.fileType',
    'AccessView.fileDirection',
    'AccessView.fileSensKey',
    'AccessView.fileSensVal',
    'AccessView.reqSensKeyNum',
    'AccessView.resSensKeyNum'
  ],
  
  // Tab 配置
  TAB_CONFIG: {
    'access': { text: '访问记录', table: 'AccessView' },
    'sensitive': { text: '敏感数据', table: 'SensitiveView' },
    'file': { text: '文件传输', table: 'FileView' }
  },

  // 列配置 - AccessView完整字段定义
  COLUMN_CONFIG: {
    'AccessView': {
      // 基础信息
      'AccessView.ts': { name: '时间', group: '基础信息', width: 'w-32' },
      'AccessView.id': { name: 'ID', group: '基础信息', width: 'w-24' },
      
      // 用户标识
      'AccessView.uid': { name: '用户标识', group: '用户标识', width: 'w-32' },
      'AccessView.sid': { name: '设备ID', group: '用户标识', width: 'w-32' },
      'AccessView.deviceFingerprint': { name: '设备指纹', group: '用户标识', width: 'w-40' },
      
      // 地理信息
      'AccessView.ip': { name: 'IP地址', group: '地理信息', width: 'w-32' },
      'AccessView.ipGeoCity': { name: '城市', group: '地理信息', width: 'w-24' },
      'AccessView.ipGeoProvince': { name: '省份', group: '地理信息', width: 'w-24' },
      'AccessView.ipGeoCountry': { name: '国家', group: '地理信息', width: 'w-24' },
      'AccessView.ipGeoIsp': { name: 'ISP', group: '地理信息', width: 'w-32' },
      
      // 请求信息
      'AccessView.method': { name: '请求方法', group: '请求信息', width: 'w-16' },
      'AccessView.host': { name: '域名', group: '请求信息', width: 'w-40' },
      'AccessView.url': { name: 'URL路径', group: '请求信息', width: 'w-auto' },
      'AccessView.urlRoute': { name: '路由', group: '请求信息', width: 'w-32' },
      'AccessView.protocol': { name: '协议', group: '请求信息', width: 'w-20' },
      'AccessView.assetName': { name: '业务名称', group: '请求信息', width: 'w-32' },
      
      // 响应信息
      'AccessView.status': { name: '状态码', group: '响应信息', width: 'w-16' },
      'AccessView.reqContentLength': { name: '请求大小', group: '响应信息', width: 'w-24' },
      'AccessView.respContentLength': { name: '响应大小', group: '响应信息', width: 'w-24' },
      'AccessView.duration': { name: '响应时间', group: '响应信息', width: 'w-20' },

      // 文件传输
      'AccessView.fileName': { name: '文件名', group: '文件传输', width: 'w-40' },
      'AccessView.fileType': { name: '文件类型', group: '文件传输', width: 'w-24' },
      'AccessView.fileDirection': { name: '动作', group: '文件传输', width: 'w-16' },

      // 处理结果
      'AccessView.resultType': { name: '处理结果', group: '处理结果', width: 'w-20' },
      'AccessView.resultRisk': { name: '命中规则', group: '处理结果', width: 'w-24' },
      'AccessView.resultAction': { name: '处理动作', group: '处理结果', width: 'w-20' },
      'AccessView.reason': { name: '原因', group: '处理结果', width: 'w-auto' },
      
      // 敏感数据
      'AccessView.reqSensKey': { name: '请求敏感字段', group: '敏感数据', width: 'w-32' },
      'AccessView.respSensKey': { name: '响应敏感字段', group: '敏感数据', width: 'w-32' },
      'AccessView.reqSensKeyNum': { name: '请求敏感字段数', group: '敏感数据', width: 'w-28' },
      'AccessView.resSensKeyNum': { name: '响应敏感字段数', group: '敏感数据', width: 'w-28' },
      'AccessView.sensScore': { name: '敏感得分', group: '敏感数据', width: 'w-20' },
      
      // 设备信息
      'AccessView.uaName': { name: '浏览器', group: '设备信息', width: 'w-24' },
      'AccessView.uaOs': { name: '操作系统', group: '设备信息', width: 'w-24' },
      'AccessView.uaOsVersion': { name: '系统版本', group: '设备信息', width: 'w-28' },
      'AccessView.uaDevice': { name: '设备类型', group: '设备信息', width: 'w-24' },
      
      // 网络拓扑
      'AccessView.topoNetwork': { name: '网络区域', group: '网络拓扑', width: 'w-24' },
      'AccessView.dstNode': { name: '目标节点', group: '网络拓扑', width: 'w-24' },
      'AccessView.nodeIp': { name: '节点IP', group: '网络拓扑', width: 'w-32' },
      'AccessView.nodeName': { name: '节点名称', group: '网络拓扑', width: 'w-32' }
    }
  },

  // 默认列配置
  DEFAULT_COLUMNS: {
    'access': [
      'AccessView.ts',
      'AccessView.ip', 
      'AccessView.method',
      'AccessView.host',
      'AccessView.url',
      'AccessView.assetName',
      'AccessView.status',
      'AccessView.resultType',
      'AccessView.resultRisk',
      'AccessView.reason'
    ],
    'sensitive': [
      'AccessView.ts',
      'AccessView.ip',
      'AccessView.url',
      'AccessView.reqSensKeyNum',
      'AccessView.resSensKeyNum',
      'AccessView.sensScore',
      'AccessView.resultType'
    ],
    'file': [
      'AccessView.ts',
      'AccessView.ip',
      'AccessView.uid',
      'AccessView.url',
      'AccessView.fileDirection',
      'AccessView.fileName',
      'AccessView.fileType',
      'AccessView.reqSensKeyNum',
      'AccessView.resSensKeyNum'
    ]
  }
};

// 导出供其他模块使用
if (typeof module !== 'undefined' && module.exports) {
  module.exports = CONFIG;
}
