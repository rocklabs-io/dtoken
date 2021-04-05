import dtoken from 'ic:canisters/registry';
import * as React from 'react';
import { render } from 'react-dom';
import Table from 'antd/es/table';
import Tag from 'antd/es/tag';
import Row from 'antd/es/row';
import Col from 'antd/es/col';
import Button from 'antd/es/button';
import Input from 'antd/es/input';
import Space from 'antd/es/space';

import 'antd/lib/row/style';
import 'antd/lib/col/style';
import 'antd/lib/table/style';
import 'antd/lib/tag/style';
import 'antd/lib/button/style';
import 'antd/lib/input/style';
import 'antd/lib/space/style';
import './home.css';
import Post from "./Post.jsx"


if (!(window).ic) {
  const { HttpAgent, IDL } = require("@dfinity/agent");
  const createAgent = require("./createAgent").default;
  (window).ic = { agent: createAgent(), HttpAgent, IDL };
}

export default class Home extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
        tokens: [],
        post_visible: false,
        // update_visible: false,
    };
  }

  async componentWillMount() {
      const tokens = await dtoken.getTokenList();
      console.log(tokens);
      this.setState({...this.state, tokens: tokens});
  }

  // showUpdateDrawer = () => {
  //     console.log("udpate");
  //     this.setState({
  //         update_visible: true,
  //     });
  // }

  showPostDrawer = () => {
      this.setState({
          post_visible: true,
      });
  }

  render() {

    const columns = [
        {
          title: 'ID',
          dataIndex: 'id',
          key: 'id',
        //   render: text => <a>{text}</a>, 
        },
        {
          title: 'Name',
          dataIndex: 'name',
          key: 'name',
        //   render: text => <a>{text}</a>, 
        },
        {
          title: 'Symbol',
          dataIndex: 'symbol',
          key: 'symbol',
        },
        {
          title: 'Decimals',
          dataIndex: 'decimals',
          key: 'decimals',
        },
        {
            title: 'TotalSupply',
            dataIndex: 'totalSupply',
            key: 'totalSupply',
        },
        {
          title: 'Owner',
          key: 'owner',
          dataIndex: 'owner',
        },
        {
          title: 'Canister ID',
          dataIndex: 'cid',
          key: 'cid',
        },
        // {
        //   title: 'Action',
        //   key: 'action',
        //   render: (row) => (
        //     <Space size="middle">
        //       <a onClick = {this.showUpdateDrawer} >Update</a>
        //       <a onClick = {() => {onDelete(row.key)}} >Delete</a>
        //     </Space>
        //   ),
        // },
    ];


    const data = this.state.tokens;

    data.forEach( item => {
        item.id = item.id.toString();
        item.decimals = item.decimals.toString();
        item.totalSupply = item.totalSupply.toString();
        item.owner = item.owner.toString();
        item.cid = item.canisterId.toString();
    });

    function refresh() {
      window.location.reload();
    }

    const { Search } = Input;

    return (
        <div>
            <Row>
                <Col span={24}>
                    <h2>
                      <a onClick={refresh} style={{ color: '#24a0ed' }} >DToken</a> : Token Issuance App for Dfinity.
                    </h2>
                </Col>
            </Row>
            <Row>
            <Col span={11}></Col>
            <Col span={4}>
                <Button type="primary" className='postbutton' size="large" onClick={this.showPostDrawer} >Create Your Token</Button>
            </Col>
            <Col span={9}></Col>
            </Row>
            <Row>
                <Col span={2}></Col>
                <Col span={20}>
                    <Table columns={columns} dataSource={data}/>
                </Col>
                <Col span={2}></Col>
            </Row>
            <Post post_visible = {this.state.post_visible} ></Post>
            {/* <Update update_visible = {this.state.update_visible} ></Update> */}
        </div> 
    );
  }
}

render(<Home />, document.getElementById('app'));